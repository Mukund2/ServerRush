import SpriteKit
import UIKit

// MARK: - Camera Controller

final class CameraController {
    let cameraNode = SKCameraNode()

    // Zoom constraints
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    private var targetScale: CGFloat = 1.0

    // Pan inertia
    private var velocity: CGPoint = .zero
    private let friction: CGFloat = 0.92
    private let velocityThreshold: CGFloat = 0.5

    // Bounds clamping
    private var gridBounds: CGRect = .zero
    private var sceneBounds: CGSize = .zero

    // Gesture state
    private var lastPanTranslation: CGPoint = .zero
    private var isPanning: Bool = false

    // Gesture recognizers (retained)
    private var pinchGesture: UIPinchGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?
    private var doubleTapGesture: UITapGestureRecognizer?

    // MARK: - Setup

    func attach(to scene: SKScene) {
        scene.addChild(cameraNode)
        scene.camera = cameraNode
        // Start slightly zoomed in for portrait — grid fills width nicely
        let initialScale: CGFloat = 0.75
        cameraNode.setScale(initialScale)
        targetScale = initialScale
    }

    func configure(gridWidth: Int, gridHeight: Int, sceneSize: CGSize) {
        sceneBounds = sceneSize
        gridBounds = IsometricUtils.gridBounds(width: gridWidth, height: gridHeight)
        let center = IsometricUtils.gridCenter(width: gridWidth, height: gridHeight)
        cameraNode.position = center
    }

    func installGestures(on view: SKView) {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        pinchGesture = pinch

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)
        panGesture = pan

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        doubleTapGesture = doubleTap
    }

    func removeGestures(from view: SKView) {
        if let g = pinchGesture { view.removeGestureRecognizer(g) }
        if let g = panGesture { view.removeGestureRecognizer(g) }
        if let g = doubleTapGesture { view.removeGestureRecognizer(g) }
    }

    // MARK: - Update (called every frame)

    func update(dt: TimeInterval) {
        // Smooth zoom interpolation
        let currentScale = cameraNode.xScale
        if abs(currentScale - targetScale) > 0.001 {
            let newScale = currentScale + (targetScale - currentScale) * 0.15
            cameraNode.setScale(newScale)
        }

        // Apply inertia when not actively panning
        if !isPanning {
            if abs(velocity.x) > velocityThreshold || abs(velocity.y) > velocityThreshold {
                cameraNode.position.x += velocity.x
                cameraNode.position.y += velocity.y
                velocity.x *= friction
                velocity.y *= friction
            } else {
                velocity = .zero
            }
        }

        clampPosition()
    }

    // MARK: - Gestures

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            targetScale = clamp(targetScale / gesture.scale, min: minScale, max: maxScale)
            gesture.scale = 1.0
        default:
            break
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let scale = cameraNode.xScale

        switch gesture.state {
        case .began:
            isPanning = true
            lastPanTranslation = .zero

        case .changed:
            let delta = CGPoint(
                x: -(translation.x - lastPanTranslation.x) * scale,
                y: (translation.y - lastPanTranslation.y) * scale
            )
            cameraNode.position.x += delta.x
            cameraNode.position.y += delta.y
            lastPanTranslation = translation

        case .ended, .cancelled:
            isPanning = false
            let v = gesture.velocity(in: view)
            velocity = CGPoint(x: -v.x * scale * 0.02, y: v.y * scale * 0.02)

        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        // Toggle between 1x and 2x zoom
        if targetScale < 1.5 {
            targetScale = 2.0
        } else {
            targetScale = 1.0
        }
    }

    // MARK: - Bounds Clamping

    private func clampPosition() {
        let scale = cameraNode.xScale
        let viewableWidth = sceneBounds.width * scale
        let viewableHeight = sceneBounds.height * scale
        let padding: CGFloat = 100 * scale

        let minX = gridBounds.minX - padding + viewableWidth / 2
        let maxX = gridBounds.maxX + padding - viewableWidth / 2
        let minY = gridBounds.minY - padding + viewableHeight / 2
        let maxY = gridBounds.maxY + padding - viewableHeight / 2

        if minX < maxX {
            cameraNode.position.x = clamp(cameraNode.position.x, min: minX, max: maxX)
        } else {
            cameraNode.position.x = gridBounds.midX
        }

        if minY < maxY {
            cameraNode.position.y = clamp(cameraNode.position.y, min: minY, max: maxY)
        } else {
            cameraNode.position.y = gridBounds.midY
        }
    }

    private func clamp(_ value: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(hi, Swift.max(lo, value))
    }
}
