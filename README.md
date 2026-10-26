# UniSwap

UniSwap is a verified, campus-only marketplace for fixed-price listings, offers, and timed auctions. Students arrange payment and handoff offline while the platform handles discovery, bidding, messaging, transaction confirmation, reputation, and moderation.

## Stack

- Next.js 16 with React 19 and TypeScript
- Supabase Auth, Postgres, Storage, Realtime, and Cron
- Vercel for the web application
- A custom SMTP provider for production authentication and notification email

## Local development

1. Install dependencies with `npm install`.
2. Copy `.env.example` to `.env.local` and add your Supabase project values.
3. Apply the SQL files in `supabase/migrations` to a Supabase project.
4. Replace the placeholder college name and email domain in `supabase/seed.sql`, then run the seed.
5. Start the app with `npm run dev`.

Run `npm run check` and `npm run build` before committing.

## Marketplace guarantees

- All marketplace data is scoped to an institution.
- Only verified, active members can access campus data.
- Maximum proxy bids are private and never readable through table access.
- Bids use database time and an atomic row lock.
- A bid in the final two minutes extends the auction by two minutes.
- Auction finalization is idempotent and runs through Supabase Cron.
- Payments are not collected by UniSwap in the pilot.

## Delivery milestones

- [x] Application scaffold and responsive discovery experience
- [x] Core database, tenant isolation, and proxy bidding
- [x] College-email OTP authentication and onboarding
- [ ] Listing creation, image upload, search, and saved items
- [ ] Offers, Buy Now, transaction handoff, and reviews
- [ ] Realtime chat, notifications, reporting, and student-admin tools
- [ ] Automated tests, pilot observability, and Vercel deployment
