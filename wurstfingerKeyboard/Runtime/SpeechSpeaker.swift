//
//  SpeechSpeaker.swift
//  Wurstfinger
//
//  Text-to-speech for the speak key action.
//

import AVFoundation

/// Wraps `AVSpeechSynthesizer` for the keyboard's speak action.
///
/// The synthesizer must stay alive for the duration of an utterance
/// (deallocating it cuts speech off), so the view model holds one instance
/// for the keyboard's lifetime. Speaking again while an utterance is in
/// flight restarts with the new text — repeated triggers read the latest
/// state instead of queueing stale readbacks.
final class SpeechSpeaker {
    private lazy var synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, locale: Locale) {
        // Deferred to the next runloop tick: audio startup inside a keyboard
        // extension is reported to misbehave when kicked off synchronously
        // from the gesture path (and it keeps the keystroke latency clean).
        DispatchQueue.main.async { [self] in
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: locale.identifier)
                ?? AVSpeechSynthesisVoice(language: nil)
            synthesizer.speak(utterance)
        }
    }
}
