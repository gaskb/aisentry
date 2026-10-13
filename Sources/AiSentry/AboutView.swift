import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("AiSentry")
                .font(.title2)
                .bold()

            Text("Versione \(AppVersion.string)")
                .foregroundStyle(.secondary)

            Text("Mostra nella barra menu la % di utilizzo dei tuoi piani/API di AI: Claude, OpenAI, Grok e Gemini.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .frame(maxWidth: 280)

            Link("Repository", destination: URL(string: "https://github.com/gaskb/aisentry")!)
                .font(.callout)

            supportText
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260)

            Text("Powered by GasKB")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 320, height: 360)
    }

    private var supportText: Text {
        guard let attributed = try? AttributedString(
            markdown: "AiSentry è gratis. Se ti torna utile, sentiti libero di [offrirmi un caffè ☕](https://ko-fi.com/gaskb)."
        ) else {
            return Text("AiSentry è gratis.")
        }
        return Text(attributed)
    }
}
