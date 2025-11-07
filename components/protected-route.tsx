'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/auth-context'
import { Skeleton } from '@/components/ui/skeleton'
import { Button } from '@/components/ui/button'
import { AlertCircle } from 'lucide-react'

interface ProtectedRouteProps {
  children: React.ReactNode
  requireAuth?: boolean
}

export function ProtectedRoute({ children, requireAuth = true }: ProtectedRouteProps) {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [showTimeout, setShowTimeout] = useState(false)

  useEffect(() => {
    if (!loading && requireAuth && !user) {
      router.push('/login')
    }
  }, [user, loading, requireAuth, router])

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      if (loading) {
        setShowTimeout(true)
      }
    }, 8000)

    return () => clearTimeout(timeoutId)
  }, [loading])

  if (loading) {
    if (showTimeout) {
      return (
        <div className="min-h-screen flex items-center justify-center p-4">
          <div className="text-center space-y-4 max-w-md">
            <AlertCircle className="h-12 w-12 mx-auto text-yellow-500" />
            <h2 className="text-xl font-semibold">Taking longer than expected...</h2>
            <p className="text-muted-foreground">
              The authentication service is taking longer than usual to respond.
            </p>
            <Button onClick={() => router.push('/login')}>
              Go to Login
            </Button>
          </div>
        </div>
      )
    }

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
