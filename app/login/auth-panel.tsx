"use client";

import { ArrowRight, CheckCircle, EnvelopeSimple, LockKey } from "@phosphor-icons/react";
import { useActionState } from "react";
import { requestOtp, verifyOtp, type AuthState } from "./actions";

const initialState: AuthState = { message: "" };

export function AuthPanel({ allowedDomain }: { allowedDomain: string }) {
  const [requestState, requestAction, requesting] = useActionState(requestOtp, initialState);
  const [verifyState, verifyAction, verifying] = useActionState(verifyOtp, initialState);
  const email = requestState.email ?? "";

  if (requestState.sent) {
    return (
      <form className="auth-form" action={verifyAction}>
        <div className="auth-icon"><EnvelopeSimple size={24} weight="bold" /></div>
        <h1>Check your inbox</h1>
        <p>We sent a one-time code to <strong>{email}</strong>.</p>
        <input type="hidden" name="email" value={email} />
        <label htmlFor="token">Verification code</label>
        <input id="token" name="token" className="otp-input" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} placeholder="000000" required autoFocus />
        {verifyState.message && <p className="form-message" role="status">{verifyState.message}</p>}
        <button className="auth-submit" type="submit" disabled={verifying}>
          {verifying ? "Checking code..." : "Enter marketplace"}<ArrowRight size={18} weight="bold" />
        </button>
        <button className="auth-link" type="button" onClick={() => window.location.reload()}>Use a different email</button>
      </form>
    );
  }

  return (
    <form className="auth-form" action={requestAction}>
      <div className="auth-icon"><LockKey size={24} weight="bold" /></div>
      <h1>Your campus, your marketplace.</h1>
      <p>Use your college email to browse, bid and sell with verified students.</p>
      <label htmlFor="email">College email</label>
      <input id="email" name="email" type="email" inputMode="email" autoComplete="email" placeholder={`name@${allowedDomain}`} required />
      {requestState.message && <p className="form-message" role="status">{requestState.message}</p>}
      <button className="auth-submit" type="submit" disabled={requesting}>
        {requesting ? "Sending code..." : "Continue with email"}<ArrowRight size={18} weight="bold" />
      </button>
      <div className="auth-assurance"><CheckCircle size={17} weight="fill" /><span>Only verified college accounts can join.</span></div>
    </form>
  );
}

