import SwiftUI
import UIKit

struct SearchTextFieldReturnKeyEnabler: UIViewRepresentable {
    final class Coordinator {
        weak var searchTextField: UISearchTextField?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let searchTextField = context.coordinator.searchTextField,
               searchTextField.window != nil {
                searchTextField.enablesReturnKeyAutomatically = false
                return
            }

            guard let searchTextField = uiView.window?.firstSearchTextField() else {
                return
            }
            searchTextField.enablesReturnKeyAutomatically = false
            context.coordinator.searchTextField = searchTextField
        }
    }
}

private extension UIView {
    func firstSearchTextField(maxDepth: Int = 8) -> UISearchTextField? {
        if let searchTextField = self as? UISearchTextField {
            return searchTextField
        }

        guard maxDepth > 0 else {
            return nil
        }

        for subview in subviews {
            if let searchTextField = subview.firstSearchTextField(maxDepth: maxDepth - 1) {
                return searchTextField
            }
        }

        return nil
    }
}
