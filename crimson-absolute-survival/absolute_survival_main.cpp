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

    // The player resolver follows protagonist swaps/transforms. Stack size is a
    // shared ItemInfo-definition-table override, so it only needs one successful
    // application; retry until the table is available. No quantity/item-consume
    // path is modified.
    while (g_running.load(std::memory_order_acquire)) {
        trinity::game::Player::RefreshSelf();
        if (!stackApplied)
            stackApplied = trinity::game::Inventory::SetAllMaxStackSizes(true, 999);
        Sleep(8);
    }

    // Restore the in-memory table before unloading when possible. Process exit
    // would discard it anyway, but explicit cleanup keeps manual ASI unload sane.
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
