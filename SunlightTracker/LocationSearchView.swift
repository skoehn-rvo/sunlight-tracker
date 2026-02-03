import SwiftUI
import MapKit
import CoreLocation

/// Search field + list of place suggestions; on select, returns coordinate.
struct LocationSearchView: View {
    let onSelect: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var completions: [MKLocalSearchCompletion] = []
    @State private var isSearching = false
    @State private var completerDelegate: CompleterDelegate?
    @FocusState private var isFieldFocused: Bool

    private let completer = MKLocalSearchCompleter()
    private let debounce = Debounce(milliseconds: 200)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search for a US city", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .onChange(of: query) { newValue in
                        debounce.fire { runCompleter(query: newValue) }
                    }
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Searching…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(completions.enumerated()), id: \.offset) { _, completion in
                        Button {
                            select(completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            //.padding(.vertical, 6)
                            //.padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .onAppear {
            isFieldFocused = true
            let delegate = CompleterDelegate(completions: $completions, isSearching: $isSearching)
            completerDelegate = delegate
            completer.delegate = delegate
            completer.resultTypes = [.address]
            completer.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.5),
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 60)
            )
        }
    }

    private func runCompleter(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            completions = []
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let item = response?.mapItems.first,
                  let coord = item.placemark.location?.coordinate else { return }
            DispatchQueue.main.async {
                onSelect(coord)
            }
        }
    }
}

/// Simple debounce for search-as-you-type.
private final class Debounce {
    private let queue: DispatchQueue
    private let interval: DispatchTimeInterval
    private var work: DispatchWorkItem?

    init(milliseconds: Int, queue: DispatchQueue = .main) {
        self.queue = queue
        self.interval = .milliseconds(milliseconds)
    }

    func fire(_ block: @escaping () -> Void) {
        work?.cancel()
        let item = DispatchWorkItem(block: block)
        work = item
        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }
}

/// Bridge MKLocalSearchCompleter (NSObject) delegate to SwiftUI state.
private final class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    @Binding var completions: [MKLocalSearchCompletion]
    @Binding var isSearching: Bool

    init(completions: Binding<[MKLocalSearchCompletion]>, isSearching: Binding<Bool>) {
        _completions = completions
        _isSearching = isSearching
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results.filter { completion in
                completion.subtitle.contains("United States") &&
                !completion.title.prefix(1).allSatisfy(\.isNumber)
            }
            self.isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.completions = []
            self.isSearching = false
        }
    }
}

#Preview {
    LocationSearchView(onSelect: { _ in }, onCancel: {})
}
