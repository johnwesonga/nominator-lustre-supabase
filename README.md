# Swim Team Voting App

Gleam Lustre frontend + Supabase (Postgres/Auth/Edge Functions) backend for a
"Most Inspirational Swimmer" end-of-season vote, sized for ~150-200 swimmers.

## Design, and why

**Parents vote on behalf of their kids (ages 6-18), including nominating
their own child.** One link per family, emailed directly to the parent —
this replaced an earlier design where swimmers themselves held the link,
which didn't work once younger kids were in scope.

**One link covers all of a parent's kids.** The link opens a page listing
every swimmer in that family, each with their own autocomplete box to pick
any teammate (including their own kid) and submit. Siblings vote
independently: one kid submitting doesn't lock the others, and each kid's
box locks for good once *their* vote lands.

**"One vote per swimmer, no changes" is still enforced in Postgres, not
the browser.** The `cast_vote(token, voter_swimmer, candidate)` function:
- confirms the token's family actually owns `voter_swimmer` (so a parent
  can't vote on someone else's kid even if they guessed a swimmer id),
- rejects it if that swimmer already has a vote recorded,
- rejects it if voting is closed,
- and a `unique` constraint on `votes.voter_id` backstops all of that even
  under a race or a replayed request.

**Admin dashboard requires a real login** (Supabase Auth), checked via an
`admins` table + `is_admin()` function, gating results, roster access, and
opening/closing voting.

## Handling ~150-200 swimmers

- **`group_name`** on each swimmer (e.g. training squad) plus a search box
  in the admin roster, so you're not scrolling 200 rows to find one kid.
- **Fewer emails than swimmers**: since siblings share a family/token, the
  notify function sends one email per *family*, not per swimmer.
- **Batched, rate-limit-aware sending**: `notify-parents` chunks emails
  through Resend's batch endpoint (100/call) rather than firing 150+
  individual requests. Swap the batch size or provider call if you use a
  different email service or it has a lower per-batch cap.

## Setup

1. **Create a Supabase project.** Run `schema.sql` in the SQL editor.
2. **Load families and swimmers.** Easiest at this scale: use Supabase
   Studio's table editor CSV import for `families` (email column;
   `family_token` auto-generates) and `swimmers` (name, group_name,
   family_id — you'll need family ids from step one before importing
   swimmers, so import families first, export the id column, then map it
   into your swimmers CSV before importing that).
3. **Create the team manager's login** in Supabase Auth, then:
   ```sql
   insert into admins (user_id) values ('<your-auth-user-uuid>');
   ```
4. **Email sending**: sign up for [Resend](https://resend.com) (or swap
   the fetch call in `supabase/functions/notify-parents/index.ts`), set
   `VOTE_BASE_URL` to your deployed app's URL, then:
   ```
   supabase secrets set RESEND_API_KEY=...
   supabase functions deploy notify-parents
   ```
5. **Gleam/Lustre app**: set `supabase_url` and `supabase_key` at the top of
   `src/supabase.gleam`, then install the Gleam dependencies and start the
   Lustre development server:
   ```
   gleam deps download
   gleam run -m lustre/dev start
   ```


## Admin workflow at season's end

1. Log in at `/admin`.
2. Click **"Email all parents their voting link"** — one email per
   family, batched.
3. Watch the roster's "Voted?" column and results tally fill in live, or
   just wait.
4. **"Close voting"** when done — blocks further votes at the database
   level immediately, not just in the UI.
5. Read the final tally off the dashboard.

## Known gaps / things to decide before rollout

- **Split households**: this assumes one parent email per swimmer. If any
  kids need two guardians to each get a link (divorced parents, etc.),
  that's a small schema extension (a join table instead of `family_id` on
  swimmers) — flag it if it's a real case for your team.
- **Lost link recovery**: only the admin can look a family's token back up
  (via `get_admin_roster`) — no self-serve resend, to avoid a phishing-style
  vector for someone fishing for another family's link.
- **Ties**: `get_results` just sorts by count; add tie-break logic if your
  team cares.
- **Styling**: functional, not styled yet — the autocomplete dropdown in
  particular will want real CSS before this goes out to parents.
