#include "durability_guard.h"

#include <cstdint>
#include <safetyhook.hpp>

#include "core/logger.h"
#include "mem/scanner.h"

namespace absolute_survival
{
    namespace
    {
        constexpr uintptr_t kMinPointer = 0x10000;

        // Current open RE for Crimson Desert exposes two durability-decrement paths:
        // the normal equipment/tool delta path and the Abyss/special-equipment delta path.
        // We hook immediately before the consuming ADD instruction and clear only the
        // 16-bit decrement operand. Item quantities are not touched here.
        constexpr const char* kSigDurabilityDelta =
            "C1 79 C5 C1 06 66 41 03 C0 66 89 45 EC C4 C1 79 C5 C1 07 66 41 03 C1 66 89";
        constexpr size_t kOffDurabilityDelta = 5;

        constexpr const char* kSigAbyssDurabilityDelta =
            "0F B7 73 02 48 8B CB 66 41 3B F5 42 8D 04 2E 66 0F 4D F8 66 89 7B 02 E8";
        constexpr size_t kOffAbyssDurabilityDelta = 11;

        SafetyHookMid g_durability{};
        SafetyHookMid g_abyssDurability{};

        void ZeroLow16(uintptr_t& reg)
        {
            reg &= ~static_cast<uintptr_t>(0xFFFFu);
        }

        void DurabilityDeltaCallback(SafetyHookContext& ctx)
        {
#if SAFETYHOOK_ARCH_X86_64
            if (ctx.rbp < kMinPointer)
                return;

            // r13w is the durability-consumption delta at this site.
            // Setting it to zero prevents wear while leaving item amount/count untouched.
            if ((ctx.r13 & 0xFFFFu) != 0)
                ZeroLow16(ctx.r13);
#endif
        }

        void AbyssDurabilityDeltaCallback(SafetyHookContext& ctx)
        {
#if SAFETYHOOK_ARCH_X86_64
            if (ctx.rbx < kMinPointer)
                return;

            // Separate special/Abyss durability decrement path.
            if ((ctx.r13 & 0xFFFFu) != 0)
                ZeroLow16(ctx.r13);
#endif
        }

        bool InstallUniqueMid(const char* name,
                              const char* sig,
                              size_t offset,
                              SafetyHookMid& out,
                              void (*callback)(SafetyHookContext&))
        {
            const size_t count = trinity::mem::CountMatches(sig, {}, 8);
            if (count != 1)
            {
                LOG_WARN("AbsoluteSurvival: %s signature count=%zu; hook skipped.", name, count);
                return false;
            }

            const uintptr_t match = trinity::mem::FindPattern(sig);
            if (!match)
            {
                LOG_WARN("AbsoluteSurvival: %s signature not found.", name);
                return false;
            }

            out = safetyhook::create_mid(reinterpret_cast<void*>(match + offset), callback);
            if (!out)
            {
                LOG_WARN("AbsoluteSurvival: %s mid-hook creation failed.", name);
                return false;
            }

            LOG_OK("AbsoluteSurvival: %s infinite-durability hook installed.", name);
            return true;
        }
    }

    bool InstallDurabilityGuard()
    {
        const bool normal = InstallUniqueMid("normal durability", kSigDurabilityDelta,
                                             kOffDurabilityDelta, g_durability,
                                             DurabilityDeltaCallback);
        const bool abyss = InstallUniqueMid("Abyss durability", kSigAbyssDurabilityDelta,
                                            kOffAbyssDurabilityDelta, g_abyssDurability,
                                            AbyssDurabilityDeltaCallback);
        return normal || abyss;
    }

    void RemoveDurabilityGuard()
    {
        g_abyssDurability = {};
        g_durability = {};
    }
}
