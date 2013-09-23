/*  Chorus member
 */

CREATE TABLE person (
    p_id INTEGER PRIMARY KEY,
    p_firstName TEXT NOT NULL,
    p_lastName TEXT NOT NULL,
    p_status TEXT NOT NULL,	/* Active, Inactive, Alumnus, Guest, Other */
    p_voicePart TEXT		/* Will be necessary eventually */
);

/*  A group of events, like the Retreat weekend.
 */

CREATE TABLE event_group (
    eg_id INTEGER PRIMARY KEY,
    eg_name TEXT NOT NULL
);

/*  A specific event.
 */

CREATE TABLE event (
    e_id INTEGER PRIMARY KEY,
    e_eg_id INTEGER REFERENCES event_group(eg_id),
    e_type TEXT NOT NULL,	/* Rehearsal, Gig, Contest, Social */
    e_name TEXT,		/* Rehearsal can be blank. */
    e_status TEXT,		/* Tentative, Confirmed, Cancelled */
    e_location TEXT,
    e_date TEXT NOT NULL,
    e_startTime TEXT NOT NULL,
    e_endTime TEXT NOT NULL
);

/*  A sign-up and attendance record that has two purposes: 1. Was this person
 *  expected? and 2. Did they attend? */

CREATE TABLE person_event (
    pe_p_id INTEGER REFERENCES person(p_id),
    pe_e_id INTEGER REFERENCES event(e_id),
    pe_response TEXT NOT NULL,
    pe_actual TEXT
);

/*  Absence (either a hiatus or a vacation). The start date is probably known,
 *  but the end date may not be know. And someone can still show up at
 *  rehearsal when they're on hiatus.
 */

CREATE TABLE person_absence (
    pa_id INTEGER PRIMARY KEY,
    pa_p_id INTEGER REFERENCES person(p_id),
    pa_startDate TEXT,
    pa_endDate TEXT,
    pa_notes TEXT
);

