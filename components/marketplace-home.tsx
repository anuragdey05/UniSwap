"use client";

import {
  ArrowUpRight, Bell, BookOpen, ChatCircle, Clock, Gavel, Heart, House,
  Laptop, MagnifyingGlass, MapPin, Plus, ShieldCheck, SlidersHorizontal,
  Sparkle, UserCircle,
} from "@phosphor-icons/react";
import Image from "next/image";
import { useMemo, useState } from "react";

type Listing = {
  id: number;
  title: string;
  price: string;
  detail: string;
  category: string;
  image: string;
  alt: string;
  badge?: string;
  auction?: boolean;
};

const listings: Listing[] = [
  { id: 1, title: "Sony WH-1000XM4", price: "₹8,500", detail: "2h 18m left", category: "Electronics", image: "https://picsum.photos/seed/black-headphones-desk/900/720", alt: "Black wireless headphones on a desk", badge: "8 bids", auction: true },
  { id: 2, title: "Engineering mathematics set", price: "₹1,250", detail: "Fixed price", category: "Books", image: "https://picsum.photos/seed/engineering-textbooks/900/720", alt: "A stack of engineering textbooks", badge: "Like new" },
  { id: 3, title: "Urban Terrain cycle", price: "₹4,800", detail: "Ends tomorrow", category: "Cycles", image: "https://picsum.photos/seed/campus-bicycle/900/720", alt: "A bicycle parked outdoors", badge: "3 bids", auction: true },
  { id: 4, title: "Study table and chair", price: "₹2,100", detail: "Open to offers", category: "Room", image: "https://picsum.photos/seed/student-study-desk/900/720", alt: "A compact wooden study desk and chair", badge: "Good" },
  { id: 5, title: "Casio scientific calculator", price: "₹650", detail: "Fixed price", category: "Electronics", image: "https://picsum.photos/seed/scientific-calculator/900/720", alt: "A scientific calculator on graph paper", badge: "Popular" },
  { id: 6, title: "Badminton racquet pair", price: "₹900", detail: "5h 42m left", category: "Sports", image: "https://picsum.photos/seed/badminton-racquets/900/720", alt: "Two badminton racquets on a court", badge: "5 bids", auction: true },
];

const categories = [
  { name: "All", icon: Sparkle },
  { name: "Electronics", icon: Laptop },
  { name: "Books", icon: BookOpen },
  { name: "Auctions", icon: Gavel },
  { name: "Room", icon: House },
];

export function MarketplaceHome() {
  const [activeCategory, setActiveCategory] = useState("All");
  const [query, setQuery] = useState("");
  const [saved, setSaved] = useState<number[]>([3]);

  const visibleListings = useMemo(() => listings.filter((listing) => {
    const categoryMatch = activeCategory === "All" || (activeCategory === "Auctions" ? listing.auction : listing.category === activeCategory);
    return categoryMatch && listing.title.toLowerCase().includes(query.toLowerCase());
  }), [activeCategory, query]);

  function toggleSaved(id: number) {
    setSaved((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }

  return (
    <div className="app-shell">
      <header className="site-header">
        <a className="brand" href="#top" aria-label="UniSwap home">
          <span className="brand-mark">U</span><span>UniSwap</span>
        </a>
        <label className="desktop-search" aria-label="Search marketplace">
          <MagnifyingGlass size={19} weight="bold" aria-hidden="true" />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search laptops, books, cycles..." />
          <kbd>⌘ K</kbd>
        </label>
        <nav className="header-actions" aria-label="Account actions">
          <button className="icon-button" aria-label="Notifications"><Bell size={21} weight="bold" /></button>
          <button className="avatar-button" aria-label="Open profile">AD</button>
          <button className="sell-button"><Plus size={18} weight="bold" />Sell an item</button>
        </nav>
      </header>

      <main id="top">
        <section className="mobile-search-wrap">
          <label className="mobile-search" aria-label="Search marketplace">
            <MagnifyingGlass size={19} weight="bold" aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="What are you looking for?" />
          </label>
        </section>

        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow"><ShieldCheck size={16} weight="fill" /> Campus verified</p>
            <h1 id="hero-title">Good stuff deserves a second semester.</h1>
            <p>Buy from people you share a campus with. Bid, chat and meet safely.</p>
            <div className="hero-actions">
              <button className="primary-action">Browse listings</button>
              <button className="secondary-action">How it works</button>
            </div>
          </div>

          <article className="hero-listing">
            <Image src="/images/campus-camera.jpg" alt="A vintage film camera on a student desk" width={1400} height={1120} priority sizes="(max-width: 900px) 100vw, 52vw" />
            <div className="hero-listing-info">
              <div><p className="listing-kicker">Live auction</p><h2>Canon AE-1 film camera</h2></div>
              <div className="hero-price"><span>Current bid</span><strong>₹6,200</strong></div>
            </div>
            <div className="auction-meta">
              <span><Gavel size={17} weight="bold" /> 12 bids</span>
              <span><Clock size={17} weight="bold" /> 47m left</span>
              <button aria-label="Open Canon AE-1 listing"><ArrowUpRight size={20} weight="bold" /></button>
            </div>
          </article>
        </section>

        <section className="trust-strip" aria-label="Marketplace assurances">
          <span><ShieldCheck size={18} weight="fill" /> College email verified</span>
          <span><ChatCircle size={18} weight="fill" /> Private in-app chat</span>
          <span><MapPin size={18} weight="fill" /> Safe campus handoff</span>
        </section>

        <section className="market-section" aria-labelledby="market-title">
          <div className="market-heading">
            <div><h2 id="market-title">Fresh on campus</h2><p>Listed by verified students near you.</p></div>
            <button className="filter-button"><SlidersHorizontal size={18} weight="bold" /> Filters</button>
          </div>

          <div className="category-row" aria-label="Listing categories">
            {categories.map(({ name, icon: Icon }) => (
              <button key={name} className={activeCategory === name ? "category active" : "category"} onClick={() => setActiveCategory(name)} aria-pressed={activeCategory === name}>
                <Icon size={18} weight="bold" />{name}
              </button>
            ))}
          </div>

          {visibleListings.length ? (
            <div className="listing-grid">
              {visibleListings.map((listing) => (
                <article className="listing-card" key={listing.id}>
                  <div className="listing-image-wrap">
                    <Image src={listing.image} alt={listing.alt} width={900} height={720} sizes="(max-width: 640px) 100vw, (max-width: 900px) 50vw, 33vw" />
                    <button className={saved.includes(listing.id) ? "save-button saved" : "save-button"} onClick={() => toggleSaved(listing.id)} aria-label={saved.includes(listing.id) ? `Unsave ${listing.title}` : `Save ${listing.title}`}>
                      <Heart size={20} weight={saved.includes(listing.id) ? "fill" : "bold"} />
                    </button>
                  </div>
                  <div className="listing-body">
                    <div className="listing-topline"><span>{listing.category}</span><span>{listing.badge}</span></div>
                    <h3>{listing.title}</h3>
                    <div className="listing-footer">
                      <strong>{listing.price}</strong>
                      <span className={listing.auction ? "auction-detail" : undefined}>{listing.auction && <Clock size={15} weight="bold" />}{listing.detail}</span>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <MagnifyingGlass size={28} weight="bold" /><h3>No listings found</h3><p>Try a different search or browse all categories.</p>
              <button onClick={() => { setQuery(""); setActiveCategory("All"); }}>Clear search</button>
            </div>
          )}
        </section>
      </main>

      <nav className="mobile-nav" aria-label="Primary navigation">
        <a className="active" href="#top"><House size={22} weight="fill" /><span>Home</span></a>
        <a href="#market-title"><MagnifyingGlass size={22} weight="bold" /><span>Explore</span></a>
        <button className="mobile-sell" aria-label="Sell an item"><Plus size={25} weight="bold" /></button>
        <a href="#messages"><ChatCircle size={22} weight="bold" /><span>Chat</span></a>
        <a href="#profile"><UserCircle size={22} weight="bold" /><span>Profile</span></a>
      </nav>
    </div>
  );
}
