"use server";

import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export type AuthState = {
  message: string;
  email?: string;
  sent?: boolean;
};

const initialError: AuthState = { message: "Please enter a valid college email." };

function readEmail(formData: FormData) {
  return String(formData.get("email") ?? "").trim().toLowerCase();
}

function emailIsAllowed(email: string) {
  const allowedDomain = (process.env.ALLOWED_COLLEGE_DOMAIN ?? "college.edu").toLowerCase();
  return email.endsWith(`@${allowedDomain}`) && email.length > allowedDomain.length + 2;
}

export async function requestOtp(_previous: AuthState, formData: FormData): Promise<AuthState> {
  const email = readEmail(formData);
  if (!emailIsAllowed(email)) return initialError;

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });

  if (error) return { message: "We could not send a code. Please wait a moment and try again.", email };
  return { message: "Check your inbox for the 6-digit code.", email, sent: true };
}

export async function verifyOtp(_previous: AuthState, formData: FormData): Promise<AuthState> {
  const email = readEmail(formData);
  const token = String(formData.get("token") ?? "").replace(/\s/g, "");

  if (!emailIsAllowed(email) || !/^\d{6}$/.test(token)) {
    return { message: "Enter the 6-digit code from your email.", email, sent: true };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({ email, token, type: "email" });
  if (error) return { message: "That code is invalid or has expired. Request a new one.", email, sent: true };

  redirect("/");
}

