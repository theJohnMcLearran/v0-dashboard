import { useAuth } from '@/contexts/auth-context'
import type { UserRole } from '@/lib/supabase/types'

export function usePermissions() {
  const { profile, user } = useAuth()

  const role: UserRole | null = profile?.role || null

  const isAdmin = role === 'admin'
  const isTeamMember = role === 'team_member'
  const isUser = role === 'user'
  const isGuest = role === 'guest'

  const canCreateRequest = isAdmin || isTeamMember || isUser
  const canViewAllRequests = isAdmin || isTeamMember
  const canEditAnyRequest = isAdmin
  const canDeleteAnyRequest = isAdmin

  const canEditRequest = (createdBy: string, assignedTo?: string | null) => {
    if (!user) return false
    if (isAdmin) return true
    if (isTeamMember && assignedTo === user.id) return true
    return createdBy === user.id
  }

  const canDeleteRequest = (createdBy: string) => {
    if (!user) return false
    if (isAdmin) return true
    return createdBy === user.id
  }

  const canCommentOnRequest = (createdBy: string) => {
    if (!user) return false
    if (isGuest) return false
    if (isAdmin || isTeamMember) return true
    return createdBy === user.id
  }

  const canViewRequest = (createdBy: string) => {
    if (!user) return false
    if (isAdmin || isTeamMember) return true
    return createdBy === user.id
  }

  const canManageUsers = isAdmin

  return {
    role,
    isAdmin,
    isTeamMember,
    isUser,
    isGuest,
    canCreateRequest,
    canViewAllRequests,
    canEditAnyRequest,
    canDeleteAnyRequest,
    canEditRequest,
    canDeleteRequest,
    canCommentOnRequest,
    canViewRequest,
    canManageUsers,
  }
}
