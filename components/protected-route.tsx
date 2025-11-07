'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/auth-context'
import { Skeleton } from '@/components/ui/skeleton'

interface ProtectedRouteProps {
  children: React.ReactNode
  requireAuth?: boolean
}

export function ProtectedRoute({ children, requireAuth = true }: ProtectedRouteProps) {
  const { user, loading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!loading && requireAuth && !user) {
      router.push('/login')
    }
  }, [user, loading, requireAuth, router])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="space-y-4 w-full max-w-md p-4">
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-64 w-full" />
          <Skeleton className="h-12 w-full" />
        </div>
      </div>
    )
  }

  if (requireAuth && !user) {
    return null
  }

  return <>{children}</>
}
