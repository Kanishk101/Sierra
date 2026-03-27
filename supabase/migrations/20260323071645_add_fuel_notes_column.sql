-- M-01 FIX: Add fuel_notes column to fuel_logs table for driver note persistence
ALTER TABLE public.fuel_logs ADD COLUMN IF NOT EXISTS fuel_notes TEXT;;
