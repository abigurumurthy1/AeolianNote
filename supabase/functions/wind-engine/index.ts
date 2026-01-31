// Wind Engine - Supabase Edge Function
// Runs every 15 minutes to update note positions based on real wind data

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENWEATHERMAP_API_KEY = Deno.env.get("OPENWEATHERMAP_API_KEY")!;

const DRIFT_FACTOR = 0.15; // Notes move at 15% of wind speed
const UPDATE_INTERVAL_HOURS = 0.25; // 15 minutes
const DISCOVERY_RADIUS_MILES = 10;
const WIND_CACHE_MINUTES = 30;

interface Note {
  id: string;
  current_lat: number;
  current_lon: number;
  journey_path: JourneyPoint[];
  status: string;
  sender_id: string;
}

interface JourneyPoint {
  lat: number;
  lon: number;
  timestamp: string;
  windSpeed: number | null;
  windBearing: number | null;
}

interface WindData {
  speed: number; // mph
  bearing: number; // degrees
}

interface User {
  id: string;
  current_lat: number;
  current_lon: number;
  home_zip_code: string;
  uses_live_location: boolean;
  push_token: string | null;
}

serve(async (req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const windCache = new Map<string, WindData>();

    // 1. Fetch all active notes
    const { data: notes, error: notesError } = await supabase
      .from("notes")
      .select("*")
      .eq("status", "active");

    if (notesError) throw notesError;
    if (!notes || notes.length === 0) {
      return new Response(JSON.stringify({ message: "No active notes" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`Processing ${notes.length} active notes`);

    // 2. Group notes by 1-degree grid cells for efficient wind data fetching
    const gridCells = groupByGridCell(notes);

    // 3. Fetch wind data for each grid cell
    for (const [cellKey, cellNotes] of gridCells) {
      const [latStr, lonStr] = cellKey.split(",");
      const lat = parseFloat(latStr);
      const lon = parseFloat(lonStr);

      // Check cache first
      let windData = await getCachedWind(supabase, cellKey);

      if (!windData) {
        windData = await fetchWindData(lat, lon);
        await cacheWindData(supabase, cellKey, windData);
      }

      windCache.set(cellKey, windData);
    }

    // 4. Update each note's position
    const updatedNotes: Note[] = [];
    const dissolvedNotes: string[] = [];

    for (const note of notes) {
      const cellKey = getGridCellKey(note.current_lat, note.current_lon);
      const windData = windCache.get(cellKey);

      if (!windData) continue;

      // Calculate new position
      const newPosition = calculateDrift(
        note.current_lat,
        note.current_lon,
        windData,
        UPDATE_INTERVAL_HOURS
      );

      // Check if new position is in an inhabited area
      const isInhabited = await checkInhabitedArea(supabase, newPosition.lat, newPosition.lon);

      if (!isInhabited) {
        // Note drifted to uninhabited area - dissolve it
        dissolvedNotes.push(note.id);
        continue;
      }

      // Update journey path
      const journeyPath = note.journey_path || [];
      journeyPath.push({
        lat: newPosition.lat,
        lon: newPosition.lon,
        timestamp: new Date().toISOString(),
        windSpeed: windData.speed,
        windBearing: windData.bearing,
      });

      updatedNotes.push({
        ...note,
        current_lat: newPosition.lat,
        current_lon: newPosition.lon,
        journey_path: journeyPath,
      });
    }

    // 5. Batch update notes
    for (const note of updatedNotes) {
      await supabase
        .from("notes")
        .update({
          current_lat: note.current_lat,
          current_lon: note.current_lon,
          journey_path: note.journey_path,
        })
        .eq("id", note.id);
    }

    // 6. Dissolve notes in uninhabited areas
    if (dissolvedNotes.length > 0) {
      await supabase
        .from("notes")
        .update({ status: "dissolved" })
        .in("id", dissolvedNotes);
    }

    // 7. Detect proximity events
    const { data: users, error: usersError } = await supabase
      .from("users")
      .select("*")
      .not("current_lat", "is", null);

    if (!usersError && users) {
      await detectProximityEvents(supabase, updatedNotes, users);
    }

    return new Response(
      JSON.stringify({
        processed: notes.length,
        updated: updatedNotes.length,
        dissolved: dissolvedNotes.length,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Wind engine error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

function groupByGridCell(notes: Note[]): Map<string, Note[]> {
  const cells = new Map<string, Note[]>();

  for (const note of notes) {
    const key = getGridCellKey(note.current_lat, note.current_lon);
    const existing = cells.get(key) || [];
    existing.push(note);
    cells.set(key, existing);
  }

  return cells;
}

function getGridCellKey(lat: number, lon: number): string {
  return `${Math.round(lat)},${Math.round(lon)}`;
}

async function getCachedWind(supabase: any, regionKey: string): Promise<WindData | null> {
  const { data, error } = await supabase
    .from("wind_cache")
    .select("*")
    .eq("region_key", regionKey)
    .gt("expires_at", new Date().toISOString())
    .single();

  if (error || !data) return null;

  return {
    speed: data.wind_speed_mph,
    bearing: data.wind_bearing_degrees,
  };
}

async function cacheWindData(supabase: any, regionKey: string, windData: WindData): Promise<void> {
  const expiresAt = new Date(Date.now() + WIND_CACHE_MINUTES * 60 * 1000);

  await supabase.from("wind_cache").upsert({
    region_key: regionKey,
    wind_speed_mph: windData.speed,
    wind_bearing_degrees: windData.bearing,
    expires_at: expiresAt.toISOString(),
  });
}

async function fetchWindData(lat: number, lon: number): Promise<WindData> {
  const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${OPENWEATHERMAP_API_KEY}&units=imperial`;

  const response = await fetch(url);
  const data = await response.json();

  return {
    speed: data.wind?.speed || 0,
    bearing: data.wind?.deg || 0,
  };
}

function calculateDrift(
  lat: number,
  lon: number,
  windData: WindData,
  hours: number
): { lat: number; lon: number } {
  // Convert wind speed from mph to miles per hour (already in mph)
  const effectiveSpeed = windData.speed * DRIFT_FACTOR;

  // Distance traveled in miles
  const distanceMiles = effectiveSpeed * hours;

  // Convert miles to meters
  const distanceMeters = distanceMiles * 1609.34;

  // Earth's radius in meters
  const earthRadius = 6371000;

  // Convert bearing to radians
  const bearingRad = (windData.bearing * Math.PI) / 180;

  // Convert current position to radians
  const lat1 = (lat * Math.PI) / 180;
  const lon1 = (lon * Math.PI) / 180;

  // Angular distance
  const angularDistance = distanceMeters / earthRadius;

  // Calculate new position using Haversine forward projection
  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(angularDistance) +
      Math.cos(lat1) * Math.sin(angularDistance) * Math.cos(bearingRad)
  );

  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(bearingRad) * Math.sin(angularDistance) * Math.cos(lat1),
      Math.cos(angularDistance) - Math.sin(lat1) * Math.sin(lat2)
    );

  return {
    lat: (lat2 * 180) / Math.PI,
    lon: (lon2 * 180) / Math.PI,
  };
}

async function checkInhabitedArea(
  supabase: any,
  lat: number,
  lon: number
): Promise<boolean> {
  // Check if there's an inhabited ZIP code within ~20 miles
  const { data, error } = await supabase.rpc("check_inhabited_area", {
    check_lat: lat,
    check_lon: lon,
    radius_miles: 20,
  });

  if (error) {
    console.error("Error checking inhabited area:", error);
    return true; // Default to inhabited to avoid false dissolves
  }

  return data;
}

async function detectProximityEvents(
  supabase: any,
  notes: Note[],
  users: User[]
): Promise<void> {
  for (const note of notes) {
    for (const user of users) {
      // Skip if user is the sender
      if (user.id === note.sender_id) continue;

      // Get user's location
      let userLat: number, userLon: number;

      if (user.uses_live_location && user.current_lat && user.current_lon) {
        userLat = user.current_lat;
        userLon = user.current_lon;
      } else if (user.home_zip_code) {
        // Look up ZIP code coordinates
        const { data: zipData } = await supabase
          .from("zip_codes")
          .select("lat, lon")
          .eq("zip_code", user.home_zip_code)
          .single();

        if (!zipData) continue;
        userLat = zipData.lat;
        userLon = zipData.lon;
      } else {
        continue;
      }

      // Calculate distance
      const distance = calculateDistance(
        note.current_lat,
        note.current_lon,
        userLat,
        userLon
      );

      if (distance <= DISCOVERY_RADIUS_MILES) {
        // Check if encounter already exists
        const { data: existingEncounter } = await supabase
          .from("note_encounters")
          .select("id")
          .eq("note_id", note.id)
          .eq("user_id", user.id)
          .single();

        if (!existingEncounter) {
          // Create new encounter
          await supabase.from("note_encounters").insert({
            note_id: note.id,
            user_id: user.id,
            distance_miles: distance,
            was_tapped: false,
          });

          // Send push notification
          if (user.push_token) {
            await sendPushNotification(user.push_token, note, distance);
          }
        }
      }
    }
  }
}

function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 3959; // Earth's radius in miles
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function sendPushNotification(
  token: string,
  note: Note,
  distance: number
): Promise<void> {
  // This would integrate with APNs
  // For now, we'll log the notification
  console.log(`Push notification to ${token}: Note ${note.id} is ${distance.toFixed(1)} miles away`);

  // In production, use APNs via a service like OneSignal or direct APNs integration
}
