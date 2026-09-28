import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { StructuredData } from "@/components/structured-data";
import { Cleanup } from "@/components/sections/cleanup";
import { Faq } from "@/components/sections/faq";
import { Features } from "@/components/sections/features";
import { FinalCta } from "@/components/sections/final-cta";
import { Hero } from "@/components/sections/hero";
import { HowItWorks } from "@/components/sections/how-it-works";
import { Models } from "@/components/sections/models";
import { Pricing } from "@/components/sections/pricing";
import { Privacy } from "@/components/sections/privacy";
import { Speed } from "@/components/sections/speed";
import { WorksEverywhere } from "@/components/sections/works-everywhere";
import { pageMetadata } from "@/lib/metadata";
import { homePageStructuredData } from "@/lib/structured-data";

export const metadata = pageMetadata({ path: "/" });

export default function HomePage() {
  return (
    <>
      <StructuredData data={homePageStructuredData()} />
      <SiteHeader />
      <main id="main">
        <Hero />
        <WorksEverywhere />
        <Speed />
        <HowItWorks />
        <Cleanup />
        <Features />
        <Privacy />
        <Models />
        <Pricing />
        <Faq />
        <FinalCta />
      </main>
      <SiteFooter />
    </>
  );
}
