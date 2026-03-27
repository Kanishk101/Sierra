
-- Add route_stops JSONB column to trips for Phase 07 multi-stop route creation.
-- Stores intermediate waypoints added via CreateTripView / RouteSelectionSheet.
--
-- Format: [{"name":"Stop Name","latitude":12.34,"longitude":56.78,"order":1}, ...]
--
-- Defaults to empty array so existing rows are unaffected.

ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS route_stops JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Index for queries that filter on non-empty stops
CREATE INDEX IF NOT EXISTS idx_trips_route_stops
  ON public.trips USING gin(route_stops)
  WHERE route_stops != '[]'::jsonb;
;
