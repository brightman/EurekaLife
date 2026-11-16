# EurekaLife Mac product prototype

This directory is a frontend-only React prototype. Do not connect microphone, screen capture, model services, native storage, or cloud uploads as part of UI work.

## S Works UI

- Read [the source-portability and UI specification](docs/ui-spec.md) before changing pages.
- Use the checked-in standard component source in `src/components/standard`, with official Mantine and Tailwind. `sources.json` records provenance and hashes.
- Preserve public props, events, refs, keyboard behavior and focus restoration. Prefer Mantine public props; custom visual differences use public `classNames` slots with static Tailwind. Native business containers may use Tailwind `className`.
- Use Lucide icons with accessible names for icon-only controls. Preserve both sidebar controls and drafts.
- Keep package versions and npm lockfile consistent; run `npm run build` and `npm run test:ui` before claiming completion.
- Unavailable source or undocumented component behavior must be reported rather than silently imitated. External contact requires explicit user authorization.
- Keep old verification evidence historical. Do not publish, commit or push without authorization; synthetic UI data only.
