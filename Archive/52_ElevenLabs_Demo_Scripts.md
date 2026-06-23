# ElevenLabs Demo Call Scripts — Phone Plus

> 5 scripts, 2 voices per call: AGENT + CUSTOMER
> Generate each with ElevenLabs Projects (multi-speaker) or TTS per turn then mix
> Target company name: Phone Plus
> Agent names match DB exactly for identity extraction to work

---

## Call 1 — Sarah Chen — Billing Dispute — Target ~88%

**Agent UUID:** ff54ac4e-020e-4872-b78a-82abf0d98f2a
**Issue category:** billing_dispute
**Outcome:** Resolved. Credit issued. Customer satisfied.

---

AGENT: Thank you for calling Phone Plus. My name is Sarah. How can I help you today?

CUSTOMER: Hi Sarah, I'm calling about my bill this month. I was charged two hundred and forty dollars but my plan is only supposed to be a hundred and twenty. Something is seriously wrong here.

AGENT: I completely understand your frustration and I'm sorry about that. Let me pull up your account right away. Can I get your account number or the phone number associated with your account?

CUSTOMER: Sure, it's 555-0142.

AGENT: Thank you. I have your account here. I can see the charge you're referring to. It looks like there was an additional international roaming charge applied on the fourteenth of this month. Did you travel internationally or make any international calls around that time?

CUSTOMER: No, absolutely not. I was home the entire month. I didn't make any international calls at all.

AGENT: I believe you completely. Looking at the call records here, I can see some data activity flagged as international but this appears to be a system error on our end. This has actually happened with a small number of accounts this billing cycle.

CUSTOMER: So I was charged for something that was your mistake?

AGENT: Yes, and I sincerely apologize for that. I'm going to reverse that charge immediately. You'll see a credit of one hundred and twenty dollars applied to your account within twenty-four hours, and your next bill will reflect the correct amount of one hundred and twenty dollars.

CUSTOMER: Okay, that's good. Will I get a confirmation of this?

AGENT: Absolutely. I'll send a confirmation email to the address on your account within the next few minutes. Is there anything else I can help you with today?

CUSTOMER: No, that takes care of it. Thank you Sarah, I appreciate how quickly you handled this.

AGENT: Of course, I'm glad we could sort that out for you. Thank you for being a Phone Plus customer and have a great day.

CUSTOMER: You too, bye.

AGENT: Goodbye.

---

## Call 2 — Marcus Williams — Tech Support — Target ~72%

**Agent UUID:** ab749e40-f969-4a45-8411-e3430ce08005
**Issue category:** tech_support
**Outcome:** Partial. Line stabilized but root cause unclear. Follow-up ticket opened.

---

AGENT: Phone Plus technical support, this is Marcus. What can I help you with?

CUSTOMER: Hi, my internet has been cutting in and out all morning. I work from home and I've had to drop two video calls already. This is really affecting my work.

AGENT: Okay so you're experiencing intermittent connectivity. Let me just ask you a few questions first. What type of router do you have? Is it the Phone Plus branded one or a third party device?

CUSTOMER: It's the one you guys provided when I signed up, so I assume it's yours.

AGENT: Right okay. And when you say cutting in and out, is the internet completely dropping or is it more like it's slow and then speeds back up?

CUSTOMER: It completely drops. The lights on the router go orange and then come back after like thirty seconds.

AGENT: Okay so the power light or the internet light?

CUSTOMER: The internet light. The top one.

AGENT: Got it. So that orange light indicates the WAN connection is dropping. That could be a few things. It could be a line issue, it could be interference, it could be a firmware issue with the router, or it could be something at the exchange level. Let me run a line diagnostic from my end. Can you stay on the line for about two minutes?

CUSTOMER: Sure.

AGENT: Okay I'm running the diagnostic now. So while that's running, what I'd also recommend is making sure your router is not placed near any large appliances or cordless phones because those can cause interference with the signal. Also if you haven't already, try to make sure the router is in a central location in your home rather than in a corner or a closed cabinet.

CUSTOMER: It's on my desk, it's been in the same place for two years and this just started today.

AGENT: Right, that's fair. Okay the diagnostic is coming back and it's showing some instability on the line but nothing that's jumping out as a clear fault. What I'm going to do is send a signal reset to your line which sometimes resolves these intermittent drops. You'll lose connection for about sixty seconds.

CUSTOMER: Okay, go ahead.

AGENT: Done. Give it about a minute and let me know if the light goes green.

CUSTOMER: Okay it's back and it's green now.

AGENT: Great. Now that might have resolved it but given that the diagnostic wasn't completely clear I'm also going to open a follow-up ticket for our network team to check the line quality over the next twenty-four hours. If the drops continue, they'll be able to identify if there's a fault further up the line.

CUSTOMER: So it might happen again?

AGENT: It's possible. If it does, the ticket is already open so you won't need to call back and explain from scratch. Is there anything else I can help with?

CUSTOMER: I guess not. I just hope it actually stays stable.

AGENT: I understand. Thank you for your patience today and I hope we get this fully resolved for you.

---

## Call 3 — Aisha Rahman — Irate Customer — Target ~91%

**Agent UUID:** 9c3ef67f-ef6e-4edc-b3c0-e329715f40d7
**Issue category:** service_complaint
**Outcome:** Fully resolved. Customer sentiment reversed from furious to satisfied.

---

AGENT: Thank you for calling Phone Plus. My name is Aisha. How can I help you today?

CUSTOMER: I need to speak to a manager right now. Your service has been down for three hours and I run a small business. Do you understand that? A business. I have had customers calling me and my phones are dead. This is completely unacceptable.

AGENT: I hear you completely and I am so sorry. Three hours of downtime for a business is absolutely unacceptable and I want to make this right for you personally right now. My name is Aisha and I am not going to transfer you anywhere. I'm going to handle this myself. Can I get your account number so I can get you to the front of the queue?

CUSTOMER: It's 778-0293. And I want to know exactly why this happened and what you're going to do about it.

AGENT: I have your account. I can see you're a business account with us and I can see the service disruption on your line. I owe you a straight answer. There was a network fault in your area that affected a cluster of business accounts starting at nine seventeen this morning. Our engineering team identified it at ten forty and the fix is being pushed right now. Your line should restore within the next fifteen minutes.

CUSTOMER: Fifteen minutes. I've already lost three hours. What does fifteen more minutes even matter at this point?

AGENT: You're right. And I'm not going to pretend that fifteen minutes makes up for three hours of lost business. What I can do right now is apply a full month's credit to your account which covers your entire monthly plan fee. I'm also escalating your account to our business priority tier which gives you a dedicated support line so if this ever happens again you skip the queue entirely.

CUSTOMER: You're crediting the whole month?

AGENT: The entire month, yes. And the business priority tier upgrade is permanent, not just for this month. You deserve that as a business customer who depends on us.

CUSTOMER: I mean... I wasn't expecting that. I appreciate it. I'm still frustrated but I appreciate that you're actually doing something.

AGENT: I completely understand the frustration. You built a business and you need to be able to rely on us. I'm going to stay on the line with you until your service restores so you don't have to call back.

CUSTOMER: You don't have to do that.

AGENT: I want to. Let's just wait together. Tell me when your line comes back.

CUSTOMER: Actually it just came back. Everything is green.

AGENT: Perfect timing. You should be fully operational now. I'm sending you a confirmation of the credit and the tier upgrade by email right now.

CUSTOMER: Thank you Aisha. You really turned this around. I was ready to cancel, honestly.

AGENT: I'm really glad we could make it right. Thank you for giving us the chance to fix it, and thank you for your patience today.

---

## Call 4 — David Park — Account Cancellation — Target ~58%

**Agent UUID:** b59bd2cc-3af9-488e-93b6-3c955c263f16
**Issue category:** account_cancellation
**Outcome:** Customer cancels. Not retained. Poor empathy throughout.

---

AGENT: Phone Plus, David speaking.

CUSTOMER: Hi, I'd like to cancel my account please.

AGENT: Okay. Can I get your account number?

CUSTOMER: It's 661-0478.

AGENT: Okay I have it here. So you want to cancel. Can I ask why?

CUSTOMER: I've been with you guys for four years and I just got an offer from another provider for half the price for the same plan.

AGENT: We're actually very competitive on pricing. What plan are they offering you?

CUSTOMER: It's the same speed, same data, but sixty dollars a month instead of a hundred and twenty.

AGENT: Our plans include a lot of additional features that other providers don't have.

CUSTOMER: Like what? I just use internet and my phone.

AGENT: Like our network reliability guarantee and our customer support.

CUSTOMER: I mean, I've had two outages in the past six months so the reliability hasn't been great honestly.

AGENT: Outages do happen across all providers. That's just the nature of the infrastructure.

CUSTOMER: Sure but the other company is offering me half the price. Is there anything you can do on price?

AGENT: I can look at what's available. The thing is our pricing reflects the quality of the service.

CUSTOMER: Right but can you match the price or not?

AGENT: I can offer you a ten dollar monthly discount for six months.

CUSTOMER: That's seventy dollars a month versus their sixty. Still more expensive.

AGENT: That's the best I'm able to do at this level.

CUSTOMER: Okay then I'd like to go ahead and cancel.

AGENT: Alright. I'll process that now. Your service will end at the end of your current billing cycle on the twenty-eighth. You'll get a confirmation email.

CUSTOMER: That's it?

AGENT: Yes, is there anything else?

CUSTOMER: No. Goodbye.

AGENT: Goodbye.

---

## Call 5 — Priya Patel — Payment Arrangement — Target ~84%

**Agent UUID:** 0845cbb9-1ab9-40b5-9127-9983925cf0fb
**Issue category:** payment_arrangement
**Outcome:** Payment plan set up. Customer retained. Minor procedural miss (forgot to confirm address).

---

AGENT: Thank you for calling Phone Plus. This is Priya. How can I help you today?

CUSTOMER: Hi Priya, I'm calling because I got a late payment notice and I'm a bit worried. I had some unexpected expenses this month and I'm not going to be able to pay the full balance by the due date.

AGENT: I'm really glad you called us proactively rather than waiting. That actually puts us in a much better position to help you. Can I get your account details?

CUSTOMER: Of course, it's 443-0817.

AGENT: Thank you. I can see your account and the balance due. First I want to say there's no need to worry. We have payment arrangement options that can help you through a difficult month without any impact to your service. Would a split payment work for you? You could pay half by the due date and the other half two weeks later.

CUSTOMER: Yes, that would actually be really helpful. Would there be any late fees?

AGENT: As long as the first payment is made by the original due date, I can waive any late fees on the second payment entirely. I'll make a note on your account right now.

CUSTOMER: That's a huge relief. Thank you. I was worried you'd just cut my service.

AGENT: We'd much rather work with you. You've been with us for three years and your account has always been in good standing. One difficult month doesn't change that.

CUSTOMER: I really appreciate that. While I have you, I've actually been meaning to ask about upgrading my internet speed. My household has grown and we're streaming on multiple devices now.

AGENT: Great timing to ask. We actually have a promotion running right now where you can upgrade to our one gigabyte plan for just twenty dollars more per month, and the first two months are at no additional charge.

CUSTOMER: That sounds good. Can you add that on from next month so it doesn't affect my current payment arrangement?

AGENT: Absolutely, I'll set it to activate on your next billing cycle so it won't impact anything you're managing this month. I'm adding that to your account now.

CUSTOMER: Perfect. So to confirm, I pay half now, half in two weeks, no late fee, and the upgrade starts next month?

AGENT: That's exactly right. You're all set. Is there anything else I can help you with today?

CUSTOMER: No, that covers everything. You've been really helpful Priya, thank you.

AGENT: My pleasure. Thank you for calling Phone Plus and have a wonderful day.

CUSTOMER: You too, bye.

AGENT: Goodbye.

---

## ElevenLabs Generation Notes

- Use two distinct voices: one professional female/male for AGENT, one varied for CUSTOMER
- Each call should be exported as a single MP3
- Suggested filenames:
  - `sarah_billing_dispute.mp3`
  - `marcus_tech_support.mp3`
  - `aisha_irate_customer.mp3`
  - `david_cancellation.mp3`
  - `priya_payment.mp3`
- Drop all 5 into `C:\Users\adeen\Desktop\batch_audio\demo_tenant\` simultaneously
