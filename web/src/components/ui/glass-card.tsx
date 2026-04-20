import { forwardRef, type HTMLAttributes } from "react";
import { cn } from "@/lib/utils";

type Variant = "default" | "strong" | "inset";

interface GlassCardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: Variant;
  edge?: boolean;
  radius?: "md" | "lg" | "xl" | "2xl";
}

const VARIANT_CLASS: Record<Variant, string> = {
  default: "aw-glass",
  strong: "aw-glass-strong",
  inset: "aw-glass-inset",
};

const RADIUS_CLASS = {
  md: "rounded-[14px]",
  lg: "rounded-[20px]",
  xl: "rounded-[28px]",
  "2xl": "rounded-[36px]",
} as const;

export const GlassCard = forwardRef<HTMLDivElement, GlassCardProps>(
  (
    { className, variant = "default", edge = true, radius = "xl", children, ...rest },
    ref,
  ) => {
    return (
      <div
        ref={ref}
        className={cn(
          "relative isolate",
          VARIANT_CLASS[variant],
          RADIUS_CLASS[radius],
          edge && "aw-glass-edge",
          className,
        )}
        {...rest}
      >
        {children}
      </div>
    );
  },
);
GlassCard.displayName = "GlassCard";
