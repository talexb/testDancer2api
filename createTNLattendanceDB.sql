/*  Chorus member
 */

CREATE TABLE person (
    p_id INTEGER PRIMARY KEY,
    p_firstName TEXT NOT NULL,
    p_lastName TEXT NOT NULL,
    p_status TEXT NOT NULL,	/* Active, Inactive, Alumnus, Guest, Other */
    p_voicePart TEXT NOT NULL
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
    e_location TEXT NOT NULL,
    e_date TEXT NOT NULL,
    e_timeStart TEXT NOT NULL,
    e_timeFinish TEXT NOT NULL
);

/*  A sign-up and attendance record that has two purposes: 1. Was this person
 *  expected? and 2. Did they attend? */

CREATE TABLE person_event (
    pe_p_id INTEGER REFERENCES person(p_id),
    pe_e_id INTEGER REFERENCES event(e_id),
    pe_expected TEXT NOT NULL,
    pe_actual TEXT NOT NULL
);
