import { ImageResponse } from "next/og";

export const size = {
  width: 512,
  height: 512,
};

export const contentType = "image/png";

export default function Icon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: 44,
          color: "white",
          background:
            "radial-gradient(circle at 50% 0%, #1f2937 0%, #0d1117 72%)",
          borderRadius: 88,
          fontFamily: "system-ui",
        }}
      >
        <div
          style={{
            fontSize: 42,
            letterSpacing: 7,
            textTransform: "uppercase",
            color: "#7dd3fc",
          }}
        >
          Ride
        </div>
        <div
          style={{
            display: "flex",
            alignItems: "flex-end",
            gap: 16,
            height: 220,
          }}
        >
          {[
            { h: 160, c: "#3b82f6" },
            { h: 192, c: "#67d5e8" },
            { h: 112, c: "#f2a14d" },
            { h: 178, c: "#3b82f6" },
          ].map((bar, index) => (
            <div
              key={index}
              style={{
                width: 72,
                height: bar.h,
                borderRadius: 20,
                background: bar.c,
                opacity: index === 1 ? 0.95 : 0.8,
              }}
            />
          ))}
        </div>
        <div
          style={{
            fontSize: 68,
            fontWeight: 700,
            letterSpacing: -2,
          }}
        >
          37.2
        </div>
      </div>
    ),
    size,
  );
}
