import SwiftUI

// MARK: - Banner Animation
struct BannerModifier: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
    }
}

// MARK: - List Item Animation
struct ListItemTransition: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
    }
}

// MARK: - Pulse Animation (for refresh indicator)
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Shake Animation (for errors)
struct ShakeModifier: ViewModifier {
    let trigger: Bool
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                withAnimation(.easeInOut(duration: 0.1).repeatCount(5, autoreverses: true)) {
                    offset = 5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    offset = 0
                }
            }
    }
}

// MARK: - Scale on Tap
struct TapScaleModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

// MARK: - Fade In on Appear
struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func bannerAnimation(isVisible: Bool) -> some View {
        modifier(BannerModifier(isVisible: isVisible))
    }
    
    func listItemTransition() -> some View {
        modifier(ListItemTransition())
    }
    
    func pulse() -> some View {
        modifier(PulseModifier())
    }
    
    func shake(trigger: Bool) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
    
    func tapScale() -> some View {
        modifier(TapScaleModifier())
    }
    
    func fadeIn() -> some View {
        modifier(FadeInModifier())
    }
}
