import Foundation
import simd

// MediaPipe world landmarks coordinate system:
//   Origin = center of hips
//   Y axis = UP (positive y → higher body part)
//   X axis = right (from camera perspective)
//   Z axis = toward camera (positive z → closer to camera)

enum Exercise: String, CaseIterable {
    case squat        = "Приседание"
    case pushup       = "Отжимание"
    case plank        = "Планка"
    case lunge        = "Выпад"
    case deadlift     = "Становая тяга"
    case shoulderPress = "Жим плечами"
}

struct FormError {
    enum Severity { case warning, critical }
    let message: String
    let severity: Severity
}

final class ExerciseAnalyzer {

    // MARK: - Squat phase state
    private enum SquatPhase { case standing, descending, ascending }
    private var squatPhase: SquatPhase = .standing
    private var squatPrevAngle: Float   = 180
    private var squatMinAngle: Float    = 180
    // Per-rep error flags — set during the rep, reported once at completion
    private var repHadValgus: Bool      = false
    private var repHadHeelLift: Bool    = false
    private var repHadForwardLean: Bool = false
    private var repValgusFrames: Int    = 0   // frames valgus detected (at bottom)
    private var repBottomFrames: Int    = 0   // frames spent below 120°
    // Rep lifecycle
    private var squatHasDescended: Bool = false
    private var squatRepConfirmed: Bool = false  // true after first complete rep

    // MARK: - Landmark indices (MediaPipe 33-point schema)
    private enum LM: Int {
        case nose = 0
        case leftShoulder = 11, rightShoulder = 12
        case leftElbow    = 13, rightElbow    = 14
        case leftWrist    = 15, rightWrist    = 16
        case leftHip      = 23, rightHip      = 24
        case leftKnee     = 25, rightKnee     = 26
        case leftAnkle    = 27, rightAnkle    = 28
        case leftHeel     = 29, rightHeel     = 30
        case leftFootIndex = 31, rightFootIndex = 32
    }

    // MARK: - Geometry helpers

    /// Angle in degrees at vertex b, between rays b→a and b→c
    private func angle(a: PoseLandmark, b: PoseLandmark, c: PoseLandmark) -> Float {
        let ba = SIMD3<Float>(a.x - b.x, a.y - b.y, a.z - b.z)
        let bc = SIMD3<Float>(c.x - b.x, c.y - b.y, c.z - b.z)
        let cos = dot(ba, bc) / (length(ba) * length(bc) + 1e-8)
        return acos(max(-1, min(1, cos))) * (180 / .pi)
    }

    private func lm(_ lms: [PoseLandmark], _ idx: LM) -> PoseLandmark { lms[idx.rawValue] }

    private func mid(_ a: PoseLandmark, _ b: PoseLandmark) -> PoseLandmark {
        PoseLandmark(x: (a.x + b.x) * 0.5,
                     y: (a.y + b.y) * 0.5,
                     z: (a.z + b.z) * 0.5,
                     visibility: min(a.visibility, b.visibility),
                     presence:   min(a.presence,   b.presence))
    }

    /// Spine lean from vertical in degrees.
    /// Forward lean (toward camera) → positive value.
    /// Straight upright → ~0°.
    private func spineLean(_ lms: [PoseLandmark]) -> Float {
        let hip      = mid(lm(lms, .leftHip),      lm(lms, .rightHip))
        let shoulder = mid(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        let dz = shoulder.z - hip.z   // forward lean → shoulder closer to camera
        let dy = shoulder.y - hip.y   // vertical rise (should be positive)
        guard abs(dy) > 0.01 else { return 90 }
        return atan2(abs(dz), abs(dy)) * (180 / .pi)
    }

    // MARK: - Public entry point

    func analyze(exercise: Exercise, landmarks: [PoseLandmark]) -> [FormError] {
        guard landmarks.count >= 33 else { return [] }
        switch exercise {
        case .squat:         return analyzeSquat(landmarks)
        case .pushup:        return analyzePushUp(landmarks)
        case .plank:         return analyzePlank(landmarks)
        case .lunge:         return analyzeLunge(landmarks)
        case .deadlift:      return analyzeDeadlift(landmarks)
        case .shoulderPress: return analyzeShoulderPress(landmarks)
        }
    }

    // MARK: - Squat

    private func analyzeSquat(_ lms: [PoseLandmark]) -> [FormError] {
        let keyIndices: [LM] = [.leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
        guard keyIndices.allSatisfy({ lms[$0.rawValue].visibility > 0.5 }) else { return [] }

        let lKneeAng = angle(a: lm(lms, .leftHip),  b: lm(lms, .leftKnee),  c: lm(lms, .leftAnkle))
        let rKneeAng = angle(a: lm(lms, .rightHip), b: lm(lms, .rightKnee), c: lm(lms, .rightAnkle))
        let avg      = (lKneeAng + rKneeAng) / 2

        // ── Phase detection (2° hysteresis) ──────────────────────────────────
        let prevPhase = squatPhase
        let delta     = avg - squatPrevAngle

        var repJustCompleted = false

        if avg >= 155 {
            if squatPhase != .standing {
                if squatHasDescended {
                    squatRepConfirmed = true
                    repJustCompleted  = true
                }
                // squatMinAngle is read for depth BEFORE this block (at justReachedBottom),
                // so reset here is safe.
                squatMinAngle     = 180
                squatHasDescended = false
            }
            squatPhase = .standing
        } else if delta < -2 {
            if prevPhase == .standing {
                // New rep starting — reset per-rep accumulators
                repHadValgus      = false
                repHadHeelLift    = false
                repHadForwardLean = false
                repValgusFrames   = 0
                repBottomFrames   = 0
            }
            squatPhase = .descending
        } else if delta > 2 {
            squatPhase = .ascending
        }

        if squatPhase != .standing { squatMinAngle = min(squatMinAngle, avg) }
        if avg < 145 { squatHasDescended = true }
        squatPrevAngle = avg

        let justReachedBottom = prevPhase == .descending && squatPhase == .ascending

        guard squatRepConfirmed else { return [] }

        var errors: [FormError] = []

        // ── Depth: fire immediately when ascending starts ─────────────────────
        if justReachedBottom && squatMinAngle > 90 {
            errors.append(FormError(
                message: "Недостаточная глубина — опустите бёдра до параллели с полом",
                severity: .warning))
        }

        // ── Accumulate form flags in the bottom zone (avg < 130°) ─────────────
        if squatPhase != .standing && avg < 130 {
            repBottomFrames += 1

            let hipW   = max(0.05, abs(lm(lms, .rightHip).x - lm(lms, .leftHip).x))
            let thresh = hipW * 0.18
            let lCave  = abs(lm(lms, .leftKnee).x)  < abs(lm(lms, .leftAnkle).x)  - thresh
            let rCave  = abs(lm(lms, .rightKnee).x) < abs(lm(lms, .rightAnkle).x) - thresh
            if lCave || rCave { repValgusFrames += 1 }

            let lHeelUp = lm(lms, .leftHeel).y  - lm(lms, .leftFootIndex).y  > 0.04
            let rHeelUp = lm(lms, .rightHeel).y - lm(lms, .rightFootIndex).y > 0.04
            if lHeelUp || rHeelUp { repHadHeelLift = true }

            if spineLean(lms) > 50 { repHadForwardLean = true }
        }

        // ── Form errors: fire at rep completion ───────────────────────────────
        if repJustCompleted {
            if repBottomFrames > 0 && repValgusFrames > repBottomFrames * 2 / 5 {
                errors.append(FormError(
                    message: "Колени завалились внутрь — разведите их по носкам",
                    severity: .critical))
            }
            if repHadForwardLean {
                errors.append(FormError(
                    message: "Чрезмерный наклон корпуса вперёд",
                    severity: .warning))
            }
            if repHadHeelLift {
                errors.append(FormError(
                    message: "Пятки отрывались от пола",
                    severity: .critical))
            }
        }

        return errors
    }

    // MARK: - Push-Up

    private func analyzePushUp(_ lms: [PoseLandmark]) -> [FormError] {
        var errors: [FormError] = []

        let shoulder = mid(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        let hip      = mid(lm(lms, .leftHip),      lm(lms, .rightHip))
        let ankle    = mid(lm(lms, .leftAnkle),    lm(lms, .rightAnkle))

        // 1. Body line (hip sag / pike).
        //    In push-up, person is horizontal. In world Y-up all of
        //    shoulder/hip/ankle are near the same Y level.
        //    shoulder.y - hip.y > 0 → hips have dropped below shoulders.
        let sagDelta = shoulder.y - hip.y
        if sagDelta > 0.08 {
            errors.append(FormError(
                message: "Таз провисает вниз — напрягите пресс",
                severity: .critical))
        } else if sagDelta < -0.10 {
            errors.append(FormError(
                message: "Таз поднят слишком высоко (пика)",
                severity: .warning))
        }

        // 2. Elbow flare.
        //    Compare elbow spread vs shoulder width.
        //    > 1.8× shoulder width = elbows excessively flared.
        let elbowW   = abs(lm(lms, .leftElbow).x - lm(lms, .rightElbow).x)
        let shoulderW = abs(lm(lms, .leftShoulder).x - lm(lms, .rightShoulder).x)
        if elbowW > shoulderW * 1.8 {
            errors.append(FormError(
                message: "Локти слишком широко — прижмите их ближе к телу",
                severity: .warning))
        }

        // 3. Full arm extension at top.
        //    Average elbow angle < 150° → arms not locked out.
        let lElbowAngle = angle(a: lm(lms, .leftShoulder),  b: lm(lms, .leftElbow),  c: lm(lms, .leftWrist))
        let rElbowAngle = angle(a: lm(lms, .rightShoulder), b: lm(lms, .rightElbow), c: lm(lms, .rightWrist))
        let avgElbow = (lElbowAngle + rElbowAngle) / 2
        if avgElbow < 150 {
            errors.append(FormError(
                message: "Выпрямите руки в верхней точке",
                severity: .warning))
        }

        // 4. Head / neck neutral.
        //    Nose should not drop significantly below shoulder line.
        if shoulder.y - lm(lms, .nose).y > 0.10 {
            errors.append(FormError(
                message: "Голова опускается — держите шею нейтрально",
                severity: .warning))
        }

        return errors
    }

    // MARK: - Plank

    private func analyzePlank(_ lms: [PoseLandmark]) -> [FormError] {
        var errors: [FormError] = []

        let shoulder = mid(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        let hip      = mid(lm(lms, .leftHip),      lm(lms, .rightHip))

        // 1. Hip alignment.
        //    In plank (horizontal), shoulder.y ≈ hip.y.
        //    Positive delta → hips sagged below shoulders.
        let delta = shoulder.y - hip.y
        if delta > 0.08 {
            errors.append(FormError(
                message: "Таз провисает — напрягите пресс и ягодицы",
                severity: .critical))
        } else if delta < -0.10 {
            errors.append(FormError(
                message: "Таз слишком высоко поднят",
                severity: .warning))
        }

        // 2. Wrists / elbows under shoulders (Z-axis depth).
        //    In plank, hands should be roughly below shoulders in Z.
        let lWristZ    = lm(lms, .leftWrist).z
        let lShoulderZ = lm(lms, .leftShoulder).z
        if abs(lWristZ - lShoulderZ) > 0.20 {
            errors.append(FormError(
                message: "Руки не под плечами — выровняйте положение",
                severity: .warning))
        }

        // 3. Head neutral.
        if shoulder.y - lm(lms, .nose).y > 0.10 {
            errors.append(FormError(
                message: "Голова опускается — смотрите в пол перед собой",
                severity: .warning))
        }

        return errors
    }

    // MARK: - Lunge

    private func analyzeLunge(_ lms: [PoseLandmark]) -> [FormError] {
        var errors: [FormError] = []

        let lKnee = angle(a: lm(lms, .leftHip),  b: lm(lms, .leftKnee),  c: lm(lms, .leftAnkle))
        let rKnee = angle(a: lm(lms, .rightHip), b: lm(lms, .rightKnee), c: lm(lms, .rightAnkle))

        // Determine the front leg: it is more bent (smaller angle)
        let frontIsLeft   = lKnee < rKnee
        let frontKneeAngle = frontIsLeft ? lKnee : rKnee
        let frontKnee  = frontIsLeft ? lm(lms, .leftKnee)       : lm(lms, .rightKnee)
        let frontAnkle = frontIsLeft ? lm(lms, .leftAnkle)      : lm(lms, .rightAnkle)
        let frontToe   = frontIsLeft ? lm(lms, .leftFootIndex)  : lm(lms, .rightFootIndex)

        // 1. Knee over toe.
        //    Z positive = closer to camera. If knee.z > toe.z the knee
        //    has passed past the toe toward the camera = knee over toe.
        if frontKnee.z - frontToe.z > 0.05 {
            errors.append(FormError(
                message: "Переднее колено выходит за носок",
                severity: .critical))
        }

        // 2. Knee depth (85–110° is ideal for a lunge).
        if frontKneeAngle > 120 {
            errors.append(FormError(
                message: "Недостаточная глубина выпада — опустите колено ниже",
                severity: .warning))
        } else if frontKneeAngle < 65 {
            errors.append(FormError(
                message: "Слишком низко — уменьшите глубину выпада",
                severity: .warning))
        }

        // 3. Torso upright: lean should be < 20° from vertical.
        if spineLean(lms) > 20 {
            errors.append(FormError(
                message: "Держите корпус прямо — не наклоняйтесь вперёд",
                severity: .warning))
        }

        // 4. Lateral knee drift: knee X should track over ankle X.
        let hipW = max(0.05, abs(lm(lms, .rightHip).x - lm(lms, .leftHip).x))
        if abs(frontKnee.x - frontAnkle.x) > hipW * 0.25 {
            errors.append(FormError(
                message: "Колено уходит в сторону — держите его над носком",
                severity: .warning))
        }

        return errors
    }

    // MARK: - Deadlift

    private func analyzeDeadlift(_ lms: [PoseLandmark]) -> [FormError] {
        var errors: [FormError] = []

        let shoulder = mid(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        let hip      = mid(lm(lms, .leftHip),      lm(lms, .rightHip))
        let knee     = mid(lm(lms, .leftKnee),     lm(lms, .rightKnee))
        let wrist    = mid(lm(lms, .leftWrist),    lm(lms, .rightWrist))

        // 1. Back rounding.
        //    Angle shoulder→hip→knee: straight back → close to 180°.
        //    < 150° = significant rounding.
        let spineAngle = angle(a: shoulder, b: hip, c: knee)
        if spineAngle < 150 {
            errors.append(FormError(
                message: "Спина округлена — держите её прямой",
                severity: .critical))
        }

        // 2. Bar path: wrists should stay close to body (Z-axis).
        //    Large Z difference → bar drifted away from legs.
        if abs(wrist.z - hip.z) > 0.15 {
            errors.append(FormError(
                message: "Штанга далеко от тела — ведите её вдоль ног",
                severity: .warning))
        }

        // 3. Shoulder shrug / forward roll.
        //    During deadlift, shoulders should not be significantly
        //    in front of the bar (wrists) in Z.
        if shoulder.z < wrist.z - 0.12 {
            errors.append(FormError(
                message: "Плечи уходят вперёд за штангу",
                severity: .warning))
        }

        // 4. Hip hinge present.
        //    Origin is at hips (y≈0). Shoulders should be noticeably
        //    above hips (shoulder.y > 0.15) during the movement.
        //    If shoulder.y is near 0, the person is not using a hip hinge.
        if shoulder.y < 0.10 {
            errors.append(FormError(
                message: "Используйте тазовый шарнир — поднимайте бёдра вместе со штангой",
                severity: .warning))
        }

        return errors
    }

    // MARK: - Shoulder Press

    private func analyzeShoulderPress(_ lms: [PoseLandmark]) -> [FormError] {
        var errors: [FormError] = []

        let lShoulder = lm(lms, .leftShoulder)
        let rShoulder = lm(lms, .rightShoulder)
        let lElbow    = lm(lms, .leftElbow)
        let rElbow    = lm(lms, .rightElbow)
        let lWrist    = lm(lms, .leftWrist)
        let rWrist    = lm(lms, .rightWrist)
        let hip       = mid(lm(lms, .leftHip), lm(lms, .rightHip))
        let shoulder  = mid(lShoulder, rShoulder)
        let wrist     = mid(lWrist, rWrist)

        // Detect press phase: wrists must be at or above shoulder height
        let isPressing = wrist.y >= shoulder.y - 0.05

        // 1. Full arm extension at lockout.
        //    Angle at shoulder between upper-arm and torso:
        //    angle(elbow, shoulder, hip) ≈ 180° when arm is straight up.
        if isPressing {
            let lPress = angle(a: lElbow, b: lShoulder, c: lm(lms, .leftHip))
            let rPress = angle(a: rElbow, b: rShoulder, c: lm(lms, .rightHip))
            if lPress < 160 || rPress < 160 {
                errors.append(FormError(
                    message: "Вытяните руки полностью вверх",
                    severity: .warning))
            }
        }

        // 2. Bar path: wrists should track above shoulders, not drift forward/back.
        //    Large Z gap between wrists and shoulders = bar is not vertical.
        if isPressing && abs(wrist.z - shoulder.z) > 0.15 {
            errors.append(FormError(
                message: "Штанга уходит вперёд/назад — жмите строго вертикально",
                severity: .warning))
        }

        // 3. Lower back arch.
        //    Forward/backward deviation of shoulder vs hip in Z.
        //    Arching = hips pushed forward (hip.z increases) while
        //    shoulders tilt backward (shoulder.z decreases).
        //    Net: shoulder.z - hip.z becomes very negative.
        let archZ = shoulder.z - hip.z
        if archZ < -0.12 {
            errors.append(FormError(
                message: "Прогиб в пояснице — напрягите пресс и ягодицы",
                severity: .warning))
        }

        // 4. Elbow position at start: elbows should be in front of shoulders
        //    (not behind) when the bar is at shoulder height.
        if !isPressing {
            let elbowBehind = (lElbow.z < lShoulder.z - 0.10) ||
                              (rElbow.z < rShoulder.z - 0.10)
            if elbowBehind {
                errors.append(FormError(
                    message: "Локти уходят назад — выведите их перед собой",
                    severity: .warning))
            }
        }

        return errors
    }
}
