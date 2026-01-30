import SwiftUI

struct CardStackView<Item, Content>: View where Item: Identifiable, Content: View {
    let items: [Item]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var currentIndex: Int
    let content: (Item) -> Content
    
    // State to track removed items (swiped away)
    @State private var removedIds: Set<Item.ID> = []
    
    // Active drag state
    @State private var offset: CGSize = .zero
    @State private var activeId: Item.ID? = nil
    
    // Callback when a card is swiped away
    var onSwipe: ((Item) -> Void)?
    
    // If true, the last card cannot be swiped away
    var keepLastCard: Bool = true
    
    init(
        items: [Item],
        currentIndex: Binding<Int>,
        cardWidth: CGFloat = 300,
        cardHeight: CGFloat = 520,
        keepLastCard: Bool = true,
        onSwipe: ((Item) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self._currentIndex = currentIndex
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.keepLastCard = keepLastCard
        self.onSwipe = onSwipe
        self.content = content
    }
    
    var visibleItems: [Item] {
        items.filter { !removedIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack {
            ForEach(visibleItems.reversed(), id: \.id) { item in
                let index = visibleItems.firstIndex(where: { $0.id == item.id }) ?? 0
                let isTop = (index == 0)
                
                CardViewWrapper(
                    item: item,
                    index: index,
                    total: visibleItems.count,
                    width: cardWidth,
                    height: cardHeight,
                    offset: isTop ? offset : .zero,
                    isDragging: isTop && (activeId == item.id),
                    dragProgress: isTop ? abs(offset.width) : 0, // Pass absolute drag distance
                    content: content
                )
                .zIndex(Double(visibleItems.count - index))
                .gesture(
                    isTop ?
                    DragGesture()
                        .onChanged { gesture in
                            // Resistance for last card
                            if keepLastCard && visibleItems.count == 1 {
                                let dampening: CGFloat = 0.2
                                offset = CGSize(width: gesture.translation.width * dampening, height: gesture.translation.height * dampening)
                            } else {
                                offset = gesture.translation
                            }
                            activeId = item.id
                        }
                        .onEnded { gesture in
                            handleDragEnd(for: item, translation: gesture.translation)
                        }
                    : nil
                )
                .allowsHitTesting(isTop)
            }
        }
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: offset)
        .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0), value: removedIds)
    }
    
    private func handleDragEnd(for item: Item, translation: CGSize) {
        let threshold: CGFloat = 100
        let shouldDismiss = abs(translation.width) > threshold || abs(translation.height) > threshold
        
        if keepLastCard && visibleItems.count == 1 {
            withAnimation {
                offset = .zero
                activeId = nil
            }
            return
        }
        
        if shouldDismiss {
            let endOffset = CGSize(
                width: translation.width > 0 ? 1000 : -1000,
                height: translation.height * 2
            )
            
            withAnimation(.easeIn(duration: 0.2)) {
                offset = endOffset
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                removedIds.insert(item.id)
                offset = .zero
                activeId = nil
                
                // Update bindings
                if currentIndex < items.count - 1 {
                    currentIndex += 1
                }
                
                onSwipe?(item)
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = .zero
                activeId = nil
            }
        }
    }
}

private struct CardViewWrapper<Item, Content: View>: View {
    let item: Item
    let index: Int
    let total: Int
    let width: CGFloat
    let height: CGFloat
    let offset: CGSize
    let isDragging: Bool
    let dragProgress: CGFloat // Absolute drag distance
    let content: (Item) -> Content
    
    // Config for stack look
    private let scaleStep: CGFloat = 0.08 // Scale difference per card
    private let yOffsetStep: CGFloat = 25  // Y offset difference per card
    private let dragThreshold: CGFloat = 150 // Reduced threshold for quicker response
    
    var body: some View {
        content(item)
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .offset(x: index == 0 ? offset.width : 0, y: index == 0 ? offset.height : 0) // Drag offset
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
    }
    
    var progressFactor: CGFloat {
        // Linear progress 0.0 ... 1.0
        let linear = min(dragProgress / dragThreshold, 1.0)
        // Ease-out curve for smoother feel (starts fast, slows down)
        // sin(x * pi / 2) is a standard ease-out
        return sin(linear * .pi / 2)
    }
    
    var scale: CGFloat {
        if index == 0 {
            return 1.0
        }
        // Current base scale based on index
        let currentScale = 1.0 - (CGFloat(index) * scaleStep)
        
        // Target scale is what it would be if index was (index - 1)
        let targetScale = 1.0 - (CGFloat(index - 1) * scaleStep)
        
        return currentScale + (targetScale - currentScale) * progressFactor
    }
    
    var yOffset: CGFloat {
        if index == 0 { return 0 }
        
        let currentY = CGFloat(index) * yOffsetStep
        let targetY = CGFloat(index - 1) * yOffsetStep
        
        return currentY + (targetY - currentY) * progressFactor
    }
    
    var opacity: CGFloat {
        if index == 0 { return 1.0 }
        
        // Base opacity for current index
        let currentOpacity = index > 3 ? 0.0 : (1.0 - (CGFloat(index) * 0.1))
        
        // Target opacity for (index - 1)
        let targetOpacity = (index - 1) > 3 ? 0.0 : (1.0 - (CGFloat(index - 1) * 0.1))
        
        return currentOpacity + (targetOpacity - currentOpacity) * progressFactor
    }
    
    var rotation: Double {
        if index == 0 {
            return Double(offset.width / 20)
        }
        return 0
    }
}
