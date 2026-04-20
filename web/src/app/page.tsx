import { Nav } from "@/components/layout/nav";
import { Footer } from "@/components/layout/footer";
import { HeroSection } from "@/components/hero/hero-section";
import { FeatureGrid } from "@/components/sections/feature-grid";
import { MapSection } from "@/components/sections/map-section";
import { ForecastSection } from "@/components/sections/forecast-section";
import { HealthSection } from "@/components/sections/health-section";
import { RoutesSection } from "@/components/sections/routes-section";
import { WidgetsSection } from "@/components/sections/widgets-section";

export default function Home() {
  return (
    <>
      <Nav />
      <main className="flex-1">
        <HeroSection />
        <FeatureGrid />
        <MapSection />
        <ForecastSection />
        <HealthSection />
        <RoutesSection />
        <WidgetsSection />
      </main>
      <Footer />
    </>
  );
}
