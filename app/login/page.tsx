import { Gavel, ShieldCheck, UsersThree } from "@phosphor-icons/react/dist/ssr";
import { AuthPanel } from "./auth-panel";

export default function LoginPage() {
  const allowedDomain = process.env.ALLOWED_COLLEGE_DOMAIN ?? "college.edu";

  return (
    <main className="auth-page">
      <section className="auth-story" aria-label="About UniSwap">
        <a className="brand auth-brand" href="/" aria-label="UniSwap home"><span className="brand-mark">U</span><span>UniSwap</span></a>
        <div className="auth-story-copy">
          <p className="eyebrow"><ShieldCheck size={16} weight="fill" /> Verified students only</p>
          <h2>Trade locally. Know who you are dealing with.</h2>
          <p>UniSwap keeps campus buying and selling inside a trusted student community.</p>
        </div>
        <div className="auth-benefits">
          <span><UsersThree size={20} weight="bold" /> Campus-only profiles</span>
          <span><Gavel size={20} weight="bold" /> Fair proxy bidding</span>
          <span><ShieldCheck size={20} weight="bold" /> Report and review tools</span>
        </div>
      </section>
      <section className="auth-panel-wrap">
        <AuthPanel allowedDomain={allowedDomain} />
        <p className="auth-legal">By continuing, you agree to the marketplace rules and privacy policy.</p>
      </section>
    </main>
  );
}
