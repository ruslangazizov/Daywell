## Daily zones

Tasks own their optional time window. Today computes zone membership from any positive-duration overlap with the current zone settings; touching an endpoint does not count. A task can appear in several zones, while tasks without a matching zone or without a time window appear in **No zone**.

All cards for an occurrence share one completion record. Timeline, Agenda and daily totals count that occurrence once. Editing, deleting or restoring zones regroups tasks without changing their times or completion records, including when viewing a past date. Overnight tasks remain on their scheduled start date.

Task storage is not implemented yet. Demo tasks that previously inherited a zone now contain explicit time windows. Any future import of the old task format must resolve inherited windows from the old zones before decoding into the current model.
