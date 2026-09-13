#include <Windows.h>
#include <atomic>
#include <cwchar>
#include <MinHook.h>

#include "game/player.h"

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

    // Rebuild the live protagonist set often enough to follow swaps/transforms.
    // Actual HP/Stamina/Spirit protection occurs synchronously in hkStatCommit.
    while (g_running.load(std::memory_order_acquire)) {
        trinity::game::Player::RefreshSelf();
        Sleep(8);
    }

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
