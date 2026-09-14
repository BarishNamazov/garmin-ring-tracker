# Vaginal ring regimen model

Status: implementation specification  
Scope: NuvaRing and etonogestrel/ethinyl estradiol generics such as EluRyng  
Not in scope: Annovera

## Safety boundary

This document defines how the app represents time. It is not a substitute for the product label, a prescriber, or emergency medical care. The app must show this disclaimer during first-run setup and in About:

> This app is a scheduling aid, not medical advice. It cannot determine whether contraception is effective. Follow the instructions supplied with your ring and contact a qualified clinician or pharmacist if a ring is late, has been out too long, or pregnancy is possible.

The app must not tell a user that they are “safe,” “protected,” or “not protected.” It may report facts about recorded times and reproduce label-directed cautions. Product instructions differ, so the user must confirm that the selected regimen is appropriate for their prescribed product.

## Default schedule

For NuvaRing and equivalent etonogestrel/ethinyl estradiol generics, the labelled schedule is:

1. Insert one ring and leave it continuously in place for 3 weeks (21 days).
2. Remove it on the same weekday, at about the same time, 3 weeks later.
3. Have a 1-week (7-day) ring-free interval.
4. Insert a new ring on the same weekday, at about the same time, exactly 4 weeks after the prior insertion, even if withdrawal bleeding has not finished.

The defaults are therefore `daysIn = 21` and `daysOut = 7`. A standard cycle anchored at insertion time `T` has:

- scheduled removal at local-calendar `T + 21 days`;
- scheduled next insertion at local-calendar `T + 28 days`.

“Calendar days” means preserving the intended local wall-clock time across daylight-saving changes; it does not always mean adding exactly 86,400 seconds per day. The technical conversion is specified in [SPEC.md](SPEC.md#time-and-calendar-rules).

These rules come from the current [NuvaRing prescribing information on DailyMed](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e14bc197-dd22-4e6e-8aa1-d6cf2242fe0f), section 2.1. The [FDA-approved NuvaRing label PDF](https://www.accessdata.fda.gov/drugsatfda_docs/label/2019/021187s037lbl.pdf) and the [EluRyng prescribing information](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c6c8512d-b258-4be5-8c2f-0f1893f198b9) describe the same 3-weeks-in/1-week-out regimen; the [NHS patient guide](https://www.nhs.uk/contraception/methods-of-contraception/vaginal-ring/how-to-use-it/) likewise summarizes 21 days in followed by 7 days out.

## Extended and continuous use

Some clinicians prescribe schedules that differ from the labelled 21/7 regimen. Examples include:

- leaving a ring in for 4 weeks before replacing it;
- replacing the ring immediately and skipping the ring-free week;
- other extended schedules, such as replacing after 5 weeks, when specifically recommended by a clinician.

The app may represent these schedules by allowing `daysIn` from 21 through 35 and `daysOut` from 0 through 7, but it must not recommend them. A non-default choice must display “Use only if this matches your product instructions or clinician’s plan.” A 0-day interval means **replace**, not “remove and wait.”

There are two importantly different evidence statements:

- The NuvaRing label says that if a ring has been left in for up to one extra week—up to 4 weeks total—the user will remain protected. The label instructs removal followed by a 1-week ring-free interval. If it has remained in longer than 4 weeks, the label directs the user to rule out pregnancy before inserting a new ring and to use an additional contraceptive method until the new ring has been used continuously for 7 days.
- [Planned Parenthood’s NuvaRing guidance](https://www.plannedparenthood.org/learn/birth-control/birth-control-vaginal-ring-nuvaring/how-do-i-use-nuvaring) states that a NuvaRing has enough hormones to last up to 5 weeks (35 days) and describes period-skipping schedules. That 35-day statement is **not** the labelled NuvaRing duration in the FDA prescribing information.

Accordingly, the UI must distinguish these ranges:

| Configured time in | App treatment |
|---|---|
| 21 days | Labelled default |
| 22–28 days | Extended schedule; show clinician/product-plan note |
| 29–35 days | Outside the FDA-labelled duration; require an explicit acknowledgement and show the note persistently in Settings |

The app must never infer that a 29–35-day schedule is appropriate from the brand name alone.

If a ring is still recorded in after 28 calendar days, the main screen must also show “Beyond the FDA-labelled 4-week duration” even when a clinician-directed 29–35-day plan is configured. This is a label-boundary notice, not an instruction to override a prescriber.

## Temporary removal

The following rules apply to NuvaRing and equivalent etonogestrel/ethinyl estradiol generics. They do **not** apply to Annovera.

### Out for less than 3 hours

If the ring is accidentally expelled or removed for less than 3 hours, the NuvaRing label says contraceptive effectiveness is not reduced. It should be rinsed with cool to lukewarm—not hot—water and reinserted as soon as possible, and no later than 3 hours.

The app records the exact out and back-in timestamps. Before 3 hours, it may display elapsed time and “Reinsert as soon as possible; follow your product instructions.” It must not encourage using the full 3-hour window.

### Out for more than 3 continuous hours in weeks 1 or 2

The label says effectiveness may be reduced. Reinsert the ring as soon as possible and use a barrier method, such as male condoms with spermicide, until the ring has been used continuously for 7 days.

The app behavior is:

- show a high-priority “Ring recorded out for more than 3 hours” warning;
- show the label-directed “Use backup contraception for 7 continuous days after reinsertion” caution;
- retain the interval in history;
- never calculate or claim contraceptive effectiveness.

### Out for more than 3 continuous hours in week 3

The label says to discard that ring and use one of two options:

1. Insert a new ring immediately, starting a new 3-week use period; or
2. Insert a new ring no later than 7 days after the prior ring was removed or expelled. This option is available only if the ring had been used continuously for at least 7 days before removal or expulsion.

For either option, the label directs use of a barrier method until the new ring has been used continuously for 7 days. The app must present both options as label information and ask the user to record what actually happened. It must not choose an option. “Insert new ring now” begins a new cycle; “Record planned insertion” changes only the reminder.

If the time out is unknown, the label says to consider the possibility of pregnancy and perform a pregnancy test before inserting a new ring. The app must show that instruction and direct the user to the label or a clinician.

### Exactly 3 hours

The label’s reduced-effectiveness rule says “more than three continuous hours.” The app changes to the over-3-hour warning only when elapsed time is strictly greater than 3:00:00. At exactly 3 hours it shows an urgent boundary warning—“3-hour limit reached; reinsert now and follow product instructions”—without silently categorizing it as either side of the threshold.

### Multiple temporary removals

Each continuous out interval is recorded separately. NuvaRing’s label expresses the threshold as a continuous interval. The app does not add separated intervals together to make a medical efficacy claim. It may show the day’s cumulative time for information, clearly labelled “recorded total,” while preserving each interval independently.

## Ring-free interval

The ring-free interval must not exceed 7 days. If it exceeds one week, the NuvaRing label says to consider the possibility of pregnancy before inserting a new ring and to use an additional barrier method, such as male condoms with spermicide, until the new ring has been used continuously for 7 days.

The app must escalate at the exact 7-day deadline:

- before the deadline: “Insert in …”;
- at the deadline: “Insert now — 7-day limit reached”;
- after the deadline: red “Ring-free interval exceeded 7 days” warning, elapsed overdue time, and the label-directed pregnancy/backup caution.

A custom `daysOut` shorter than 7 days produces an earlier planned insertion reminder. It never moves the medical 7-day ceiling later. If the ring was removed early or late, the app shows both the configured plan and the absolute 7-day-from-actual-removal ceiling, and uses the earlier time as the next required action.

## Annovera is different and unsupported

Annovera is one reusable segesterone acetate/ethinyl estradiol vaginal system used for 13 cycles: 21 days in and 7 days out per cycle, up to 273 in-use days. It is not a monthly disposable NuvaRing-type product. Its prescribing information uses a different temporary-removal threshold: more than 2 continuous or cumulative hours during the 21-day in period triggers backup instructions.

This app version must display “Annovera is not supported” and must not apply its NuvaRing-oriented 3-hour logic to Annovera. See the [FDA Annovera label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2022/209627s003lbl.pdf).

## State-machine implications

The medical schedule maps to these user-observable states:

| State | Entry condition | Primary action |
|---|---|---|
| `SETUP` | No active insertion recorded | Record insertion |
| `RING_IN` | Inserted, not removed, before scheduled removal/replacement | Remove or replace at the scheduled time |
| `RING_FREE` | Removed, before the earlier of planned insertion and the 7-day ceiling | Insert at the displayed time |
| `OVERDUE_REMOVE` | Ring still recorded in at/after scheduled removal/replacement | Record what happened; follow product plan |
| `OVERDUE_INSERT` | Ring recorded out at/after planned insertion | Insert and record; follow label caution if the 7-day ceiling was exceeded |
| `TEMP_OUT` | A temporary-out event is open | Reinsert and record; warn at the 3-hour boundary |

`OVERDUE_REMOVE` and `OVERDUE_INSERT` are both rendered as the product phase `OVERDUE`, with a distinct required action. `TEMP_OUT` is an overlay on the current cycle state, not a separate cycle phase.

## Sources and review requirement

- [NuvaRing current prescribing information, DailyMed](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e14bc197-dd22-4e6e-8aa1-d6cf2242fe0f)
- [NuvaRing FDA label PDF, 2019](https://www.accessdata.fda.gov/drugsatfda_docs/label/2019/021187s037lbl.pdf)
- [EluRyng prescribing information, DailyMed](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c6c8512d-b258-4be5-8c2f-0f1893f198b9)
- [NHS: How to use the vaginal ring](https://www.nhs.uk/contraception/methods-of-contraception/vaginal-ring/how-to-use-it/)
- [Planned Parenthood: How to use the birth control ring](https://www.plannedparenthood.org/learn/birth-control/birth-control-vaginal-ring-nuvaring/how-do-i-use-nuvaring)
- [Annovera FDA label PDF, 2022](https://www.accessdata.fda.gov/drugsatfda_docs/label/2022/209627s003lbl.pdf)

Before release, a clinician or pharmacist familiar with the marketed products in the target region should review all medical copy. Label URLs and wording should be rechecked for every release because prescribing information can change.
