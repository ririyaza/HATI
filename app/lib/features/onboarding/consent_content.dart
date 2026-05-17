import 'package:flutter/material.dart';

const List<InlineSpan> kConsentStudyAboutSpans = [
  TextSpan(
    text: '1. What is this study about?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'You are invited to participate in a research study developing and evaluating HATI, a mobile application designed to help students who experience high levels of social anxiety symptoms. The app includes a virtual companion named "Hati" that provides gamified social scenarios, emotion tracking, and coping strategies in a safe, private environment.\n'
        'This study aims to understand whether such an application can help students better recognize their emotional patterns and practice coping skills in social situations.\n\n',
  ),
  TextSpan(
    text: '2. Why am I being invited to participate?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'You are being invited because:\n'
        'You are a third-year undergraduate student at West Visayas State University.\n'
        'You have scored above 40 on the Social Phobia Inventory (SPIN) screening, indicating high social anxiety symptoms.\n'
        'You are not currently diagnosed with Social Anxiety Disorder or receiving active professional mental health treatment.\n'
        'You are 20 years of age or older.\n\n',
  ),
  TextSpan(
    text: '3. What will happen if I agree to participate?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'If you agree to participate, you will be asked to:\n'
        'Install the application on your mobile device with the assistance of the researchers.\n'
        'Complete an initial SPIN assessment within the app (if not already completed).\n'
        'Use the HATI application for a period of two weeks.\n'
        'During use, you will engage with gamified social scenarios where you will type responses. You may also be given the option to provide brief voice recordings to help the app detect emotional cues.\n'
        'The app will track your emotional patterns over time and provide adaptive feedback from the virtual companion.\n'
        'At the end of the study period, you will complete another SPIN assessment and a GAD-7 assessment.\n'
        'Participants will be asked to share their experience with the app through a feedback form.\n\n',
  ),
  TextSpan(
    text: '4. Is HATI a substitute for professional mental health treatment?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'No. HATI is a self-help support tool designed for non-clinical use. It is not a diagnostic instrument and does not replace professional psychological or psychiatric treatment.\n'
        'If you have concerns about your mental health, you may reach out to the WVSU University Guidance and Counseling Office:\n'
        'Location: Hometel, Ground Floor, West Visayas State University\n'
        'Contact:\n'
        'Email:',
  ),
];

const List<InlineSpan> kConsentDataCollectedSpans = [
  TextSpan(
    text: '5. What type of data will be collected?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'The following data will be collected:\n'
        'Assessment Data: Your SPIN and GAD-7 scores.\n'
        'App Usage Data: Your interactions with the app, including scenario choices, emotion logs, and progress tracking.\n'
        'Text Input: The responses you type during gamified scenarios.\n'
        'Audio Input: Optional voice recordings you choose to provide for emotion detection.\n'
        'Feedback Data: Interview responses if you participate in the optional feedback session.\n\n',
  ),
  TextSpan(
    text: '6. How will my data be used?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'Your data will be used for research purposes only, including:\n'
        'Analyzing the usability and effectiveness of the HATI application.\n'
        'Writing academic publications (thesis, presentation).\n'
        'Improving future versions of the application.\n\n',
  ),
  TextSpan(
    text: '7. Will my data be kept private?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'Yes. The research team will protect your privacy in the following ways:\n'
        'Your data will be assigned a unique participant code for anonymization. Your name will not be stored with your research data and will only be accessed by one person in the research team.\n'
        'All data will be stored on password-protected, encrypted servers accessible only to the core research team.\n'
        'This study complies with the Philippine Data Privacy Act of 2012 (RA 10173).\n'
        'Data transmission from third-party services used for emotion detection (text and voice analysis) will be encrypted and will not be permanently stored by these services.\n'
        'Your personal identity will never be revealed in any publications or presentations resulting from this research. Only grouped or anonymized data will be reported.',
  ),
];

const List<InlineSpan> kConsentRisksSupportSpans = [
  TextSpan(
    text: '8. What are the potential risks of participating?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'The risks are minimal but may include:\n'
        'Temporary Discomfort: Reflecting on anxiety-provoking social situations may cause mild emotional discomfort. This is normal and similar to what you might experience in daily life.\n'
        'Privacy Risks: As with any digital application, there is a small risk of data breach, though we take extensive precautions to prevent this.\n'
        'If you experience significant distress while using the app, you are encouraged to contact the research team using the information provided at the end of this form. You will also be provided with contact information for the university guidance and counseling office and other mental health resources.\n\n',
  ),
  TextSpan(
    text: '9. What are the potential benefits of participating?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'While there is no guarantee of direct benefit, possible benefits include:\n'
        'Greater awareness of your emotional patterns and triggers.\n'
        'Learning and practicing coping strategies for social anxiety.\n'
        'Contributing to research that may help other students with similar experiences.\n'
        'Access to a free, private tool for emotional self-monitoring.',
  ),
];

const List<InlineSpan> kConsentParticipantRightsSpans = [
  TextSpan(
    text: '10. Is my participation mandatory?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'No. Your participation is completely voluntary. You may choose not to participate, or you may withdraw from the study at any time without any penalty, loss of benefits, or negative consequences to your academic standing.\n'
        'If you withdraw, any data collected from you will be deleted and not used in the research.\n\n',
  ),
  TextSpan(
    text: '11. Who can I contact if I have questions or concerns?\n',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  TextSpan(
    text:
        'If you have any questions about this study, please contact:\n'
        'Researcher: Precious Mae J. Taleon\n'
        'Email: preciousmae.taleon@wvsu.edu.ph\n'
        'Contact Number: 09275311191\n'
        'Researcher: Jaspher John E. Samalburo\n'
        'Email: jaspherjohn.samalburo@wvsu.edu.ph\n'
        'Contact Number: 09\n'
        'If you experience distress, you can contact:\n'
        'The National Centre for Mental Health Crisis Hotline\n'
        'Tel: (02) 989-8727 (telephone)\n'
        'Tel: (0917) 899-8727 (cellphone)',
  ),
];
