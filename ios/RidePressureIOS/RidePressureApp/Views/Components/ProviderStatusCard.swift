import SwiftUI

struct ProviderStatusCard: View {
    let providers: [ProviderSnapshot]
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROVIDER STATUS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RidePressurePalette.tertiaryText)

            Text("Only real provider price observations get green, orange, or red. Unsupported providers remain neutral.")
                .font(.system(size: 13))
                .foregroundStyle(RidePressurePalette.secondaryText)

            ForEach(providers) { provider in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.provider.displayName.uppercased())
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(provider.supportLevel.label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(hex: "6B7280"))
                        }

                        Spacer()

                        PillBadge(
                            label: provider.statusLabel,
                            tone: provider.tone
                        )
                    }

                    Text(provider.note)
                        .font(.system(size: 12))
                        .foregroundStyle(RidePressurePalette.secondaryText)

                    HStack(spacing: 8) {
                        Text(provider.sourceBlend.label)
                        if let freshnessHours = provider.freshnessHours {
                            Text("\(freshnessHours)h old")
                        } else {
                            Text("No live price")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "6B7280"))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "11161F"))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
            }

            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "94A3B8"))
            }
        }
        .padding(18)
        .background(RidePressurePalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 20, y: 24)
    }
}
