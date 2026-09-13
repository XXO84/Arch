#include <Windows.h>
#include <atomic>
#include <cwchar>
#include <MinHook.h>

#include "game/inventory.h"
#include "game/player.h"
#include "durability_guard.h"

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

DWORD WINAPI AbsoluteSurvivalThread(void*)
{
    if (!IsCrimsonDesertHost()) return 0;
    if (MH_Initialize() != MH_OK) return 1;

    trinity::game::Player::Install();
    trinity::game::Inventory::Install();
    absolute_survival::InstallDurabilityGuard();

    bool stackApplied = false;
    DWORD lastResolve = 0;

    // Resource protection is deliberately two-layered:
    //  1) the stat-commit hook blocks normal HP/Stamina/Spirit writes immediately;
    //  2) ForceAbsoluteResources continuously restores the already-resolved player
    //     gauges, covering current game builds where a resource write bypasses that
    //     commit funnel. Player discovery itself is only refreshed ~60 Hz so this
    //     fallback does not repeatedly walk the complete character list.
    while (g_running.load(std::memory_order_acquire)) {
        const DWORD now = GetTickCount();
        if (lastResolve == 0 || now - lastResolve >= 16) {
            trinity::game::Player::RefreshSelf();
            lastResolve = now;
        }

        trinity::game::Player::ForceAbsoluteResources();

        if (!stackApplied)
            stackApplied = trinity::game::Inventory::SetAllMaxStackSizes(true, 999);

        Sleep(1);
    }

    if (stackApplied)
        trinity::game::Inventory::SetAllMaxStackSizes(false, 999);

    absolute_survival::RemoveDurabilityGuard();
    trinity::game::Inventory::Remove();
    trinity::game::Player::Remove();
    MH_Uninitialize();
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