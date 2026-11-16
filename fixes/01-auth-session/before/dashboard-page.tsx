// BEFORE — app/dashboard/page.tsx (server component)
import { createClient } from '@/lib/supabase/server'

export default async function Dashboard() {
  const supabase = await createClient()
  // Same problem as the middleware: the session object comes straight from
  // the cookie and is not verified, so session.user.id can be spoofed.
  const { data: { session } } = await supabase.auth.getSession()
  const { data: tasks } = await supabase
    .from('tasks')
    .select('id,title,status,due_at')
    .eq('assignee_id', session?.user.id)
  return <TaskList tasks={tasks ?? []} />
}
