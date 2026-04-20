"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { useEffect, useMemo, useRef, useState } from "react";
import * as THREE from "three";
import { useGeolocation } from "@/hooks/use-geolocation";
import { useAirAnalysis } from "@/hooks/use-air-quality";
import { aqiMeta } from "@/lib/aqi";

interface ParticleSystemProps {
  count: number;
  aqi: number;
  mouse: React.MutableRefObject<{ x: number; y: number }>;
}

function ParticleSystem({ count, aqi, mouse }: ParticleSystemProps) {
  const pointsRef = useRef<THREE.Points>(null);
  const materialRef = useRef<THREE.PointsMaterial>(null);

  // Scale density + velocity with AQI — dirtier air, more particles, slower drift
  const intensity = Math.min(aqi / 200, 1);
  const color = useMemo(() => new THREE.Color(aqiMeta(aqi).color), [aqi]);

  const { positions, velocities } = useMemo(() => {
    const pos = new Float32Array(count * 3);
    const vel = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 40;
      pos[i * 3 + 1] = (Math.random() - 0.5) * 26;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 12;
      vel[i * 3] = (Math.random() - 0.5) * 0.008;
      vel[i * 3 + 1] = Math.random() * 0.003 + 0.001;
      vel[i * 3 + 2] = (Math.random() - 0.5) * 0.004;
    }
    return { positions: pos, velocities: vel };
  }, [count]);

  // Tween material color on AQI change
  useEffect(() => {
    if (!materialRef.current) return;
    materialRef.current.color.copy(color);
  }, [color]);

  useFrame((state) => {
    if (!pointsRef.current) return;
    const geo = pointsRef.current.geometry as THREE.BufferGeometry;
    const posAttr = geo.attributes.position as THREE.BufferAttribute;
    const arr = posAttr.array as Float32Array;
    const t = state.clock.elapsedTime;

    for (let i = 0; i < count; i++) {
      const idx = i * 3;
      // Gentle sinusoidal drift with per-particle phase
      arr[idx] += velocities[idx] + Math.sin(t * 0.2 + i * 0.01) * 0.003;
      arr[idx + 1] += velocities[idx + 1];
      arr[idx + 2] += velocities[idx + 2];

      // Respawn off-screen
      if (arr[idx + 1] > 14) arr[idx + 1] = -13;
      if (arr[idx] > 22) arr[idx] = -22;
      if (arr[idx] < -22) arr[idx] = 22;
    }
    posAttr.needsUpdate = true;

    // Mouse parallax on whole system
    pointsRef.current.rotation.y = THREE.MathUtils.lerp(
      pointsRef.current.rotation.y,
      mouse.current.x * 0.1,
      0.02,
    );
    pointsRef.current.rotation.x = THREE.MathUtils.lerp(
      pointsRef.current.rotation.x,
      mouse.current.y * 0.08,
      0.02,
    );
  });

  return (
    <points ref={pointsRef}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          args={[positions, 3]}
        />
      </bufferGeometry>
      <pointsMaterial
        ref={materialRef}
        size={0.08 + intensity * 0.05}
        color={color}
        transparent
        opacity={0.35 + intensity * 0.25}
        sizeAttenuation
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </points>
  );
}

interface Props {
  count?: number;
  className?: string;
}

export function PM25Field({ count = 1800, className }: Props) {
  const geo = useGeolocation();
  const analysis = useAirAnalysis(geo.coords);
  const aqi = analysis.data?.combined_aqi ?? 45;

  const mouse = useRef({ x: 0, y: 0 });
  const [enabled, setEnabled] = useState(true);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    setEnabled(!reduced);

    const onMove = (e: MouseEvent) => {
      mouse.current.x = (e.clientX / window.innerWidth) * 2 - 1;
      mouse.current.y = -((e.clientY / window.innerHeight) * 2 - 1);
    };
    window.addEventListener("mousemove", onMove, { passive: true });
    return () => window.removeEventListener("mousemove", onMove);
  }, []);

  if (!enabled) return null;

  return (
    <div
      className={className}
      style={{
        position: "fixed",
        inset: 0,
        pointerEvents: "none",
        zIndex: 1,
        opacity: 0.6,
      }}
      aria-hidden
    >
      <Canvas
        camera={{ position: [0, 0, 18], fov: 60 }}
        dpr={[1, 2]}
        gl={{ antialias: false, alpha: true }}
      >
        <ParticleSystem count={count} aqi={aqi} mouse={mouse} />
      </Canvas>
    </div>
  );
}
