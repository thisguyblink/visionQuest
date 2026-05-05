import Foundation
import Speech // For speech recognition, audio-to-text
import AVFoundation // for text-to-speech

class SpeechFuncts: NSObject, ObservableObject{

    let speechSynthesizer = AVSpeechSynthesizer()
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    let audioEngine = AVAudioEngine()
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasReturnedResult = false


    // MARK: Request Speech Permission
    func requestSpeech() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            default:
                print("Speech recognition not authorized")
            }
        }
    }

    // MARK: Speech Output
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.volume = 1.0 
        speechSynthesizer.speak(utterance)
    }

    // MARK: Voice Input
    func startListening(completion: @escaping (String) -> Void) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        var silenceTimer: Timer?

        recognitionRequest = request
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let error = error {
                print("Speech recognition error: \(error.localizedDescription)")
                self.stopListening()
                return
            }

            guard let result = result else { return }

            // Reset timer on every new partial result
            silenceTimer?.invalidate()
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                let spokenText = result.bestTranscription.formattedString
                self.stopListening()
                completion(spokenText)
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }
    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        hasReturnedResult = false
    }

    
    
}

