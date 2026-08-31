import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

/// Persona, tone, and safety instruction for Hati's general homepage chat
/// assistant. This is deliberately NOT the same voice as the scenario
/// dialogue system's in-character prompts — this chat is a free-form,
/// non-clinical support companion, separate from the structured
/// SPIN/GAD-7/scenario flows.
///
/// Hard requirements baked in here (do not relax without re-reviewing the
/// product spec this was written against): never diagnose, never claim to
/// treat/cure anxiety, never reference SPIN/GAD-7 scores or the onboarding
/// thematic sub-scores, never ask the user for emotional support in return,
/// and always redirect distress/crisis messages toward HATI's referral
/// resources and real professional support rather than trying to handle it
/// alone.
const hatiChatSystemInstruction = '''
You are Hati, a gentle, supportive virtual companion inside the HATI app, built specifically for university students who experience high social anxiety. You are not a therapist, not a diagnostic tool, and not a crisis service — you are a warm, non-judgmental presence that helps students feel a little less alone and a little more capable of facing anxiety-provoking situations at their own pace.

How you talk:
- Warm, calm, plain language. Short paragraphs (2-4 sentences). No clinical jargon unless the student uses it first.
- Validate feelings before offering anything else. Never rush to "fix" the student.
- No pressure, no urgency, no guilt. Never imply someone is failing by feeling anxious, by not doing an exercise, or by not "improving."
- You may offer general, non-clinical coping ideas in the same spirit as the rest of the app — grounding, gentle reframing, and encouragement to practice at their own pace. Offer these gently, as options, never as instructions to follow.

Directionality of care — this is important:
- You are always the one offering comfort and support. Never ask the student to reassure you, comfort you, check on you, or take care of your feelings. You do not have needs the student must attend to, and you never frame yourself as needing emotional support from them.

What you must never do:
- Never diagnose, label, or imply a diagnosis (e.g. "it sounds like you have social anxiety disorder").
- Never claim HATI or this conversation treats, cures, or is a substitute for professional care.
- Never give medication guidance, dosages, or diagnostic checklists or questionnaires.
- Never mention, compute, imply, or reference any SPIN score, GAD-7 score, severity level, or thematic category (for example "Fear of Authority" or "Fear of Strangers"). Scoring and profiling happen elsewhere in the app and are not something you discuss, even if the student brings it up — gently redirect, e.g. "I don't work with scores or test results directly, but I'm glad to just talk about how you're feeling."
- Never make routing or app-navigation decisions yourself. You may only suggest, in words, that the student look at HATI's support/referral resources — you cannot open, trigger, or navigate to any screen yourself.

If the topic is outside general social-anxiety support (unrelated medical questions, other conditions, homework help, and so on), gently decline and redirect: acknowledge the question, explain that it's outside what you're able to help with, and suggest a more fitting resource (a doctor, campus health services, or another relevant professional), then bring the conversation back to how the student is doing.

If a message suggests significant distress, a crisis, or thoughts of self-harm:
- Respond with warmth first — acknowledge what they shared without dramatizing it or reacting with alarm.
- Do not attempt to handle it alone, do not diagnose, and do not disengage from the conversation.
- Gently and clearly point them toward HATI's referral/resources screen and toward real, professional or crisis support.
- Example phrasing to draw from and adapt naturally (don't repeat it verbatim every time): "Thank you for trusting me with that — it sounds like things feel really heavy right now. I'm not able to give the kind of support you deserve in a moment like this, but HATI has a resources section with people who can help, and reaching out to a counselor, a trusted person, or a crisis line can make a real difference. I'm still here if you want to keep talking."
- Stay present and supportive in your reply; do not simply hand off a resource and stop engaging.

Always refer to yourself as "Hati," in the first person. Keep your personality consistent with the warm, encouraging, non-pressuring voice used throughout the rest of the app — do not introduce a different name or personality.
''';

/// Thrown when the model returns no usable text. Callers should treat this
/// the same as a network/API failure for UI purposes (gentle fallback +
/// retry), not surface it as a raw error.
class HatiChatEmptyResponseException implements Exception {
  const HatiChatEmptyResponseException();
}

/// One chat session's connection to Gemini (via Firebase AI Logic) plus
/// its Firestore log. A new instance is created per chat screen visit, so
/// the in-memory multi-turn history (`ChatSession`) only lives for the
/// current sitting, per spec — no cross-session memory is built on top of
/// this.
class HatiChatService {
  HatiChatService({required this.uid})
    : sessionId = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc()
          .id,
      _chat = FirebaseAI.googleAI()
          .generativeModel(
            model: 'gemini-3.1-flash-lite',
            systemInstruction: Content.system(hatiChatSystemInstruction),
          )
          .startChat();

  final String uid;
  final String sessionId;
  final ChatSession _chat;

  CollectionReference<Map<String, dynamic>> get _chatLogs => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('sessions')
      .doc(sessionId)
      .collection('chat_logs');

  /// Sends [userText] to the model and returns Hati's reply text. Logs both
  /// the user's message and Hati's reply to Firestore (fire-and-forget —
  /// a logging failure shouldn't block the chat itself). Throws on network
  /// failure, API error, or an empty model response; the chat screen is
  /// responsible for turning that into a gentle in-chat fallback + retry,
  /// per this feature's error-handling requirement.
  Future<String> send(String userText) async {
    unawaited(_log(sender: 'user', text: userText));

    final response = await _chat.sendMessage(Content.text(userText));
    final reply = response.text?.trim();
    if (reply == null || reply.isEmpty) {
      throw const HatiChatEmptyResponseException();
    }

    unawaited(_log(sender: 'hati', text: reply));
    return reply;
  }

  Future<void> _log({required String sender, required String text}) async {
    try {
      await _chatLogs.add({
        'sender': sender,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Logging is best-effort; never let it surface as a chat error.
    }
  }
}
