import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase/client'
import type { Request } from '@/lib/supabase/types'

export function useRequests(filters?: {
  status?: string
  priority?: string
  createdBy?: string
  assignedTo?: string
}) {
  const [requests, setRequests] = useState<Request[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    const fetchRequests = async () => {
      try {
        setLoading(true)
        let query = supabase
          .from('requests')
          .select('*')
          .order('created_at', { ascending: false })

        if (filters?.status) {
          query = query.eq('status', filters.status)
        }
        if (filters?.priority) {
          query = query.eq('priority', filters.priority)
        }
        if (filters?.createdBy) {
          query = query.eq('created_by', filters.createdBy)
        }
        if (filters?.assignedTo) {
          query = query.eq('assigned_to', filters.assignedTo)
        }

        const { data, error: fetchError } = await query

        if (fetchError) throw fetchError

        setRequests(data || [])
        setError(null)
      } catch (err) {
        setError(err as Error)
        console.error('Error fetching requests:', err)
      } finally {
        setLoading(false)
      }
    }

    fetchRequests()
  }, [filters?.status, filters?.priority, filters?.createdBy, filters?.assignedTo])

  const refetch = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('requests')
        .select('*')
        .order('created_at', { ascending: false })

      if (filters?.status) {
        query = query.eq('status', filters.status)
      }
      if (filters?.priority) {
        query = query.eq('priority', filters.priority)
      }
      if (filters?.createdBy) {
        query = query.eq('created_by', filters.createdBy)
      }
      if (filters?.assignedTo) {
        query = query.eq('assigned_to', filters.assignedTo)
      }

      const { data, error: fetchError } = await query

      if (fetchError) throw fetchError

      setRequests(data || [])
      setError(null)
    } catch (err) {
      setError(err as Error)
      console.error('Error fetching requests:', err)
    } finally {
      setLoading(false)
    }
  }

  return { requests, loading, error, refetch }
}
