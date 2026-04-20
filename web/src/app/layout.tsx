import type { Metadata, Viewport } from "next";
import { Geist, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";
import { AuroraBackground } from "@/components/ui/aurora-background";
import { PM25Field } from "@/components/particles/pm25-field";
import { ThemeScript } from "@/components/theme/theme-script";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains-mono",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "AirWay · Breathable Intelligence",
    template: "%s · AirWay",
  },
  description:
    "Navegación y monitoreo respiratorio en tiempo real. Rutas más limpias, predicción ML de calidad del aire y análisis biométrico de exposición.",
  applicationName: "AirWay",
  authors: [{ name: "AirWay Team" }],
  keywords: [
    "air quality",
    "AQI",
    "PM2.5",
    "smart routing",
    "NASA",
    "environmental health",
  ],
};

export const viewport: Viewport = {
  themeColor: "#0a1d4d",
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="es"
      className={`${geistSans.variable} ${jetbrainsMono.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <head>
        <ThemeScript />
      </head>
      <body className="relative min-h-full flex flex-col">
        <AuroraBackground />
        <Providers>
          <PM25Field />
          <div className="relative z-10 flex flex-col min-h-dvh">{children}</div>
        </Providers>
      </body>
    </html>
  );
}
