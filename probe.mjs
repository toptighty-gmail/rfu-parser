import { createClient } from '@supabase/supabase-js'
import crypto from 'node:crypto'

const url = process.env.SUPABASE_URL
const anon = process.env.SUPABASE_ANON_KEY

if (!url || !anon) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY')
  process.exit(1)
}

const projectRef = new URL(url).hostname.split('.')[0]
console.log('SUPABASE_URL present:', !!url)
console.log('Project ref:', projectRef)

const supabase = createClient(url, anon, {
  auth: { persistSession: false, autoRefreshToken: false },
})

const probeId = crypto.randomUUID()
const probeRow = {
  id: probeId,
  division: 'PROBE_DIVISION',
  date: '2099-01-01',
  time: '15:00',
  home_team: 'PROBE_HOME',
  away_team: 'PROBE_AWAY',
  score: 'v',
  status: 'Scheduled',
  notes: 'env-write-probe',
  is_custom: true,
}

const insertRes = await supabase.from('custom_fixtures').insert(probeRow).select()
console.log('INSERT status:', insertRes.status)
console.log('INSERT error:', insertRes.error)
console.log('INSERT rows:', insertRes.data?.length ?? 0)

const readRes = await supabase
  .from('custom_fixtures')
  .select('id, division, notes, created_at')
  .eq('id', probeId)
  .maybeSingle()

console.log('READ status:', readRes.status)
console.log('READ error:', readRes.error)
console.log('READ row found:', !!readRes.data)

const deleteRes = await supabase.from('custom_fixtures').delete().eq('id', probeId)
console.log('DELETE status:', deleteRes.status)
console.log('DELETE error:', deleteRes.error)