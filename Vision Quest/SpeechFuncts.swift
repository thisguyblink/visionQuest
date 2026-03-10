import Foundation
import Speech // For speech recognition, audio-to-text
import AVFoundation // for text-to-speech

class SpeechFuncts {

    let speechSynthesizer = AVSpeechSynthesizer()
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    let audioEngine = AVAudioEngine()

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
        speechSynthesizer.speak(utterance)
    }

    // MARK: Voice Input
    func startListening(completion: @escaping (String) -> Void) {
        // collects speech to send to recognition
        let request = SFSpeechAudioBufferRecognitionRequest()
        // mic input to hold live mic audio
        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = false

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        speechRecognizer?.recognitionTask(with: request) { result, error in
            if let error = error {
                print("Speech recognition error: \(error.localizedDescription)")
                return
            }

            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                completion(spokenText)
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }
}