#include <Windows.h>
#include <atomic>
#include <cstdint>
#include <cwchar>
#include <string>
#include <vector>
#include <MinHook.h>

#include "core/logger.h"
#include "game/inventory.h"
#include "game/player.h"
#include "durability_guard.h"
#include "resource_guard.h"

#pragma comment(lib, "Version.lib")

namespace {
std::atomic<bool> g_running{true};

bool IsCrimsonDesertHost()
{
    wchar_t path[MAX_PATH]{};
    const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) return false;
    const wchar_t* name = wcsrchr(path, L'\\');
    name = name ? name + 1 : path;
    return _wcsicmp(name, L"CrimsonDesert.exe") == 0;
}

void ResetAuditLog()
{
    char root[MAX_PATH]{};
    const DWORD n = GetEnvironmentVariableA("LOCALAPPDATA", root, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) return;
    const std::string dir = std::string(root) + "\\CrimsonDesert_AbsoluteSurvival";
    CreateDirectoryA(dir.c_str(), nullptr);
    const std::string path = dir + "\\AbsoluteSurvival.log";
    DeleteFileA(path.c_str());
}

void LogHostVersion()
{
    wchar_t path[MAX_PATH]{};
    const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) return;

    char utf8[MAX_PATH * 3]{};
    WideCharToMultiByte(CP_UTF8, 0, path, -1, utf8, static_cast<int>(sizeof(utf8)), nullptr, nullptr);
    LOG("AbsoluteSurvival: host=%s", utf8);

    DWORD dummy = 0;
    const DWORD size = GetFileVersionInfoSizeW(path, &dummy);
    if (!size) {
        LOG_WARN("AbsoluteSurvival: host file-version resource unavailable.");
        return;
    }
    std::vector<std::uint8_t> buffer(size);
    if (!GetFileVersionInfoW(path, 0, size, buffer.data())) return;
    VS_FIXEDFILEINFO* info = nullptr;
    UINT infoSize = 0;
    if (!VerQueryValueW(buffer.data(), L"\\", reinterpret_cast<void**>(&info), &infoSize) ||
        !info || infoSize < sizeof(VS_FIXEDFILEINFO))
        return;

    LOG_OK("AbsoluteSurvival: host file version %u.%u.%u.%u",
           HIWORD(info->dwFileVersionMS), LOWORD(info->dwFileVersionMS),
           HIWORD(info->dwFileVersionLS), LOWORD(info->dwFileVersionLS));
}

DWORD WINAPI AbsoluteSurvivalThread(void*)
{
    if (!IsCrimsonDesertHost()) return 0;

    ResetAuditLog();
    LOG_OK("AbsoluteSurvival v1.2.0 AUDITED-2.02 starting.");
    LogHostVersion();

    if (MH_Initialize() != MH_OK) {
        LOG_ERR("AbsoluteSurvival: MinHook initialization failed.");
        return 1;
    }

    trinity::game::Player::Install();
    const bool inventoryInstalled = trinity::game::Inventory::Install();
    const bool resourceDirect = absolute_survival::InstallResourceGuard();
    const bool durability = absolute_survival::InstallDurabilityGuard();

    LOG(inventoryInstalled ? "AbsoluteSurvival: item-definition resolver installed."
                           : "AbsoluteSurvival: item-definition resolver unavailable; Stack 999 disabled.");
    LOG(resourceDirect ? "AbsoluteSurvival: at least one direct resource-cost hook installed."
                       : "AbsoluteSurvival: direct cost hooks unavailable; StatCommit + hard-lock fallback remains.");
    LOG(durability ? "AbsoluteSurvival: at least one durability hook installed."
                   : "AbsoluteSurvival: durability signatures did not resolve; durability protection unavailable.");

    bool stackApplied = false;
    bool stackReported = false;
    DWORD lastResolve = 0;
    DWORD lastDiag = 0;
    int lastHp = -1, lastStamina = -1, lastSpirit = -1;

    // Three-layer player-resource protection:
    //  1) direct stamina/spirit negative-delta guards where current signatures match;
    //  2) Trinity's pattern-scanned StatCommit hook;
    //  3) a high-frequency hard-lock of ONLY already-resolved protagonist entries.
    // Discovery itself is throttled to ~60 Hz to avoid repeatedly walking the
    // complete character manager.
    while (g_running.load(std::memory_order_acquire)) {
        const DWORD now = GetTickCount();
        if (lastResolve == 0 || now - lastResolve >= 16) {
            trinity::game::Player::RefreshSelf();
            lastResolve = now;
        }

        trinity::game::Player::ForceAbsoluteResources();

        // The patched SetAllMaxStackSizes is conservative in v1.2.0: it only
        // raises an already-active native cap >1 and never flips non-stackable
        // definitions (gear/special/container items) to stackable.
        if (inventoryInstalled && !stackApplied)
            stackApplied = trinity::game::Inventory::SetAllMaxStackSizes(true, 999);
        if (stackApplied && !stackReported) {
            LOG_OK("AbsoluteSurvival: safe native Stack >=999 override applied.");
            stackReported = true;
        }

        if (lastDiag == 0 || now - lastDiag >= 1000) {
            int hp = 0, stamina = 0, spirit = 0;
            trinity::game::Player::GetResolvedCounts(&hp, &stamina, &spirit);
            if (hp != lastHp || stamina != lastStamina || spirit != lastSpirit) {
                LOG("AbsoluteSurvival: resolved player entries HP=%d Stamina=%d Spirit=%d",
                    hp, stamina, spirit);
                lastHp = hp;
                lastStamina = stamina;
                lastSpirit = spirit;
            }
            lastDiag = now;
        }

        Sleep(1);
    }

    if (stackApplied)
        trinity::game::Inventory::SetAllMaxStackSizes(false, 999);

    absolute_survival::RemoveDurabilityGuard();
    absolute_survival::RemoveResourceGuard();
    trinity::game::Inventory::Remove();
    trinity::game::Player::Remove();
    MH_Uninitialize();
    LOG("AbsoluteSurvival: shutdown complete.");
    return 0;
}
} // namespace

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(module);
        g_running.store(true, std::memory_order_release);
        HANDLE thread = CreateThread(nullptr, 0, AbsoluteSurvivalThread, nullptr, 0, nullptr);
        if (thread) CloseHandle(thread);
    } else if (reason == DLL_PROCESS_DETACH) {
        g_running.store(false, std::memory_order_release);
    }
    return TRUE;
}
