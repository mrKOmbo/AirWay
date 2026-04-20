import { cn } from "@/lib/utils";

export function LivePill({
  children,
  className,
}: {
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-2 rounded-full bg-white/70 backdrop-blur border border-aw-border px-3 py-1 text-xs font-medium text-aw-primary shadow-sm",
        className,
      )}
    >
      <span className="aw-live-dot" />
      {children ?? "Live"}
    </span>
  );
}
