#include "resource_guard.h"

#include <cstdint>
#include <safetyhook.hpp>

#include "core/logger.h"
#include "game/player.h"
#include "mem/scanner.h"

namespace absolute_survival
{
    namespace
    {
        constexpr std::uintptr_t kMinPointer = 0x10000;

        // Current-ish runtime RE paths. These are not fixed addresses: each is
        // pattern-scanned and must resolve uniquely before a hook is installed.
        constexpr const char* kSigStaminaAb00 =
            "0F B7 D7 49 8B CE E8 ?? ?? ?? ?? 48 8B F0 48 85 DB 74 ?? 33 C0 66 89 44 24 20 38 46 53";
        constexpr std::size_t kOffStaminaAb00 = 11;

        constexpr const char* kSigSpiritDeltaPrimary =
            "48 89 ?? 48 89 ?? E8 ?? ?? ?? ?? 84 C0 75 ?? 48 8B 5C 24 ?? 48 8B 74 24 ?? 48 83 C4 ?? 5F C3";
        constexpr std::size_t kOffSpiritDeltaPrimary = 6;
        constexpr const char* kSigSpiritDeltaFallback =
            "49 89 D8 48 89 FA 48 89 C1 48 89 C6 E8 ?? ?? ?? ?? 84 C0 75 ?? 48 8B 5C 24 30 48 8B 74 24 40 48 83 C4 20 5F C3";
        constexpr std::size_t kOffSpiritDeltaFallback = 12;

        SafetyHookMid g_stamina{};
        SafetyHookMid g_spirit{};

        void StaminaCallback(SafetyHookContext& ctx)
        {
#if SAFETYHOOK_ARCH_X86_64
            const std::uintptr_t entry = ctx.rax;
            const auto delta = static_cast<std::int64_t>(ctx.rbx);
            if (entry < kMinPointer || delta >= 0)
                return;

            // The same callback can carry stamina-shaped writes for a nearby
            // spirit/action pool. Only touch entries already resolved from a
            // live protagonist; mount/NPC/enemy resources are untouched.
            if (trinity::game::Player::IsTrackedStaminaEntry(entry) ||
                trinity::game::Player::IsTrackedSpiritEntry(entry))
            {
                ctx.rbx = 0;
            }
#endif
        }

        void SpiritCallback(SafetyHookContext& ctx)
        {
#if SAFETYHOOK_ARCH_X86_64
            const std::uintptr_t entry = ctx.rcx;
            const auto delta = static_cast<std::int64_t>(ctx.r8);
            if (entry < kMinPointer || delta >= 0)
                return;

            if (trinity::game::Player::IsTrackedSpiritEntry(entry))
                ctx.r8 = 0;
#endif
        }

        bool InstallUnique(const char* name,
                           const char* sig,
                           std::size_t offset,
                           SafetyHookMid& out,
                           void (*callback)(SafetyHookContext&))
        {
            const std::size_t count = trinity::mem::CountMatches(sig, 8);
            if (count != 1)
            {
                LOG_WARN("AbsoluteSurvival: %s signature count=%zu; hook skipped.", name, count);
                return false;
            }
            const std::uintptr_t match = trinity::mem::FindPattern(sig);
            if (!match)
                return false;
            out = safetyhook::create_mid(reinterpret_cast<void*>(match + offset), callback);
            if (!out)
            {
                LOG_WARN("AbsoluteSurvival: %s hook creation failed.", name);
                return false;
            }
            LOG_OK("AbsoluteSurvival: %s direct resource-cost hook installed.", name);
            return true;
        }

        bool InstallSpirit()
        {
            if (InstallUnique("spirit-delta primary", kSigSpiritDeltaPrimary,
                              kOffSpiritDeltaPrimary, g_spirit, SpiritCallback))
                return true;
            return InstallUnique("spirit-delta fallback", kSigSpiritDeltaFallback,
                                 kOffSpiritDeltaFallback, g_spirit, SpiritCallback);
        }
    }

    bool InstallResourceGuard()
    {
        const bool stamina = InstallUnique("stamina-ab00", kSigStaminaAb00,
                                           kOffStaminaAb00, g_stamina, StaminaCallback);
        const bool spirit = InstallSpirit();
        LOG(stamina ? "AbsoluteSurvival: direct stamina guard ready."
                    : "AbsoluteSurvival: direct stamina guard unavailable; StatCommit + hard-lock remain active.");
        LOG(spirit ? "AbsoluteSurvival: direct spirit guard ready."
                   : "AbsoluteSurvival: direct spirit guard unavailable; StatCommit + hard-lock remain active.");
        return stamina || spirit;
    }

    void RemoveResourceGuard()
    {
        g_spirit = {};
        g_stamina = {};
    }
}
