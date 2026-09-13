#include <Windows.h>
#include <atomic>
#include <cwchar>
#include <MinHook.h>

#include "core/state.h"
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

void EnforceAbsoluteProfile()
{
    auto& st = trinity::State::Get();

    // Inventory amounts/consumption remain vanilla. Only the definition-wide
    // maximum stack cap is overridden.
    st.invStackSize = true;
    st.invStackSizeVal = 999;
    st.invSlotSize = false;
}

DWORD WINAPI AbsoluteSurvivalThread(void*)
{
    if (!IsCrimsonDesertHost()) return 0;
    if (MH_Initialize() != MH_OK) return 1;

    EnforceAbsoluteProfile();

    trinity::game::Player::Install();
    trinity::game::Inventory::Install();
    absolute_survival::InstallDurabilityGuard();

    // Rebuild live protagonist state, keep the 999-stack definition override
    // applied across save loads, and never touch item quantities.
    while (g_running.load(std::memory_order_acquire)) {
        EnforceAbsoluteProfile();
        trinity::game::Player::RefreshSelf();
        trinity::game::Inventory::Tick();
        Sleep(8);
    }

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
