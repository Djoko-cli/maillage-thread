import SwiftUI

/// « Maillage Thread devient Maillage IoT » (spec de Maillage IoT, section 4.2), en haut du menu de la barre : le lien
/// de telechargement de Maillage IoT et « Exporter pour Maillage IoT… », remplace par « Export en cours… » pendant
/// un export.
struct BandeauMaillageIoT: View {
    let export: ExportMaillageIoT
    let exporter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Maillage Thread devient Maillage IoT", systemImage: "arrow.triangle.merge")
                .font(.callout.weight(.semibold))
            Text("Une seule app pour les réseaux Thread et Zigbee. L'export reprend l'historique, le journal, les surnoms, les pièces et les réglages.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Link("Télécharger Maillage IoT", destination: ExportMaillageIoT.lienTelechargement)
                if export.enCours {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("Export en cours…").foregroundStyle(.secondary)
                    }
                } else {
                    Button("Exporter pour Maillage IoT…", action: exporter)
                        .buttonStyle(.link)
                }
            }
            .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
