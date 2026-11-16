// AFTER — app/dashboard/page.tsx (server component)
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export default async function Dashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser() // verified by Supabase Auth
  if (!user) redirect('/login')
  const { data: tasks } = await supabase
    .from('tasks')
    .select('id,title,status,due_at')
    .eq('assignee_id', user.id) // RLS still enforces workspace access (fix 02)
  return <TaskList tasks={tasks ?? []} />
}
