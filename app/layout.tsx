import type { Metadata } from "next";
import { GeistSans } from "geist/font/sans";
import "./globals.css";

export const metadata: Metadata = {
  title: "UniSwap | Your campus marketplace",
  description: "Buy, sell and bid safely within your college community.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className={GeistSans.className}>{children}</body>
    </html>
  );
}
