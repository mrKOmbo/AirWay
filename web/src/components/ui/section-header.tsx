import { cn } from "@/lib/utils";

interface SectionHeaderProps {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  className?: string;
  align?: "left" | "center";
}

export function SectionHeader({
  eyebrow,
  title,
  subtitle,
  className,
  align = "left",
}: SectionHeaderProps) {
  return (
    <header
      className={cn(
        "flex flex-col gap-3 max-w-2xl",
        align === "center" && "items-center text-center mx-auto",
        className,
      )}
    >
      {eyebrow && (
        <div className="flex items-center gap-2">
          <span className="h-px w-6 bg-aw-border-strong" />
          <span className="aw-eyebrow">{eyebrow}</span>
        </div>
      )}
      <h2 className="aw-display text-3xl md:text-4xl lg:text-5xl text-aw-primary">
        {title}
      </h2>
      {subtitle && (
        <p className="text-base md:text-lg text-aw-ink-soft leading-relaxed">
          {subtitle}
        </p>
      )}
    </header>
  );
}
