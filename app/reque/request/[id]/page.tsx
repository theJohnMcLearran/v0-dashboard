'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { format } from 'date-fns'
import { ProtectedRoute } from '@/components/protected-route'
import { AppSidebar } from '@/components/app-sidebar'
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from '@/components/ui/breadcrumb'
import { Separator } from '@/components/ui/separator'
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from '@/components/ui/sidebar'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Skeleton } from '@/components/ui/skeleton'
import { supabase } from '@/lib/supabase/client'
import { useAuth } from '@/contexts/auth-context'
import { usePermissions } from '@/hooks/use-permissions'
import { toast } from 'sonner'
import { Edit, Trash2, Calendar, User, Clock } from 'lucide-react'
import type { Request, RequestComment, RequestActivity, Profile, RequestStatus, RequestPriority } from '@/lib/supabase/types'

export default function RequestDetailPage() {
  return (
    <ProtectedRoute>
      <RequestDetailContent />
    </ProtectedRoute>
  )
}

function RequestDetailContent() {
  const params = useParams()
  const router = useRouter()
  const { user } = useAuth()
  const { canEditRequest, canDeleteRequest, canCommentOnRequest } = usePermissions()

  const [request, setRequest] = useState<Request | null>(null)
  const [comments, setComments] = useState<RequestComment[]>([])
  const [activity, setActivity] = useState<RequestActivity[]>([])
  const [profiles, setProfiles] = useState<Map<string, Profile>>(new Map())
  const [loading, setLoading] = useState(true)
  const [commentText, setCommentText] = useState('')
  const [submittingComment, setSubmittingComment] = useState(false)

  const requestId = params.id as string

  useEffect(() => {
    fetchRequestDetails()
  }, [requestId])

  const fetchRequestDetails = async () => {
    try {
      setLoading(true)

      const [{ data: requestData }, { data: commentsData }, { data: activityData }] = await Promise.all([
        supabase.from('requests').select('*').eq('id', requestId).single(),
        supabase.from('request_comments').select('*').eq('request_id', requestId).order('created_at', { ascending: false }),
        supabase.from('request_activity').select('*').eq('request_id', requestId).order('created_at', { ascending: false }),
      ])

      if (!requestData) {
        toast.error('Request not found')
        router.push('/reque/my-requests')
        return
      }

      setRequest(requestData)
      setComments(commentsData || [])
      setActivity(activityData || [])

      const userIds = new Set<string>([
        requestData.created_by,
        ...(requestData.assigned_to ? [requestData.assigned_to] : []),
        ...(commentsData || []).map((c) => c.user_id),
        ...(activityData || []).map((a) => a.user_id),
      ])

      const { data: profilesData } = await supabase
        .from('profiles')
        .select('*')
        .in('id', Array.from(userIds))

      const profilesMap = new Map<string, Profile>()
      profilesData?.forEach((profile) => {
        profilesMap.set(profile.id, profile)
      })
      setProfiles(profilesMap)
    } catch (error) {
      console.error('Error fetching request:', error)
      toast.error('Failed to load request')
    } finally {
      setLoading(false)
    }
  }

  const handleStatusChange = async (newStatus: RequestStatus) => {
    if (!request || !user) return

    try {
      const { error } = await supabase
        .from('requests')
        .update({ status: newStatus })
        .eq('id', request.id)

      if (error) throw error

      setRequest({ ...request, status: newStatus })
      toast.success('Status updated')
      fetchRequestDetails()
    } catch (error) {
      console.error('Error updating status:', error)
      toast.error('Failed to update status')
    }
  }

  const handlePriorityChange = async (newPriority: RequestPriority) => {
    if (!request || !user) return

    try {
      const { error } = await supabase
        .from('requests')
        .update({ priority: newPriority })
        .eq('id', request.id)

      if (error) throw error

      setRequest({ ...request, priority: newPriority })
      toast.success('Priority updated')
      fetchRequestDetails()
    } catch (error) {
      console.error('Error updating priority:', error)
      toast.error('Failed to update priority')
    }
  }

  const handleSubmitComment = async () => {
    if (!commentText.trim() || !user || !request) return

    setSubmittingComment(true)

    try {
      const { error } = await supabase
        .from('request_comments')
        .insert({
          request_id: request.id,
          user_id: user.id,
          comment_text: commentText.trim(),
        })

      if (error) throw error

      setCommentText('')
      toast.success('Comment added')
      fetchRequestDetails()
    } catch (error) {
      console.error('Error adding comment:', error)
      toast.error('Failed to add comment')
    } finally {
      setSubmittingComment(false)
    }
  }

  const handleDeleteRequest = async () => {
    if (!request || !user || !confirm('Are you sure you want to delete this request?')) return

    try {
      const { error } = await supabase
        .from('requests')
        .delete()
        .eq('id', request.id)

      if (error) throw error

      toast.success('Request deleted')
      router.push('/reque/my-requests')
    } catch (error) {
      console.error('Error deleting request:', error)
      toast.error('Failed to delete request')
    }
  }

  if (loading) {
    return (
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <div className="p-6 space-y-4">
            <Skeleton className="h-12 w-full" />
            <Skeleton className="h-64 w-full" />
            <Skeleton className="h-32 w-full" />
          </div>
        </SidebarInset>
      </SidebarProvider>
    )
  }

  if (!request) {
    return null
  }

  const statusColors = {
    new: 'bg-blue-500/10 text-blue-700 border-blue-500/20',
    in_progress: 'bg-yellow-500/10 text-yellow-700 border-yellow-500/20',
    under_review: 'bg-purple-500/10 text-purple-700 border-purple-500/20',
    completed: 'bg-green-500/10 text-green-700 border-green-500/20',
    rejected: 'bg-red-500/10 text-red-700 border-red-500/20',
  }

  const priorityColors = {
    normal: 'bg-gray-500/10 text-gray-700 border-gray-500/20',
    high: 'bg-orange-500/10 text-orange-700 border-orange-500/20',
    urgent: 'bg-red-500/10 text-red-700 border-red-500/20',
  }

  const creatorProfile = profiles.get(request.created_by)
  const canEdit = canEditRequest(request.created_by, request.assigned_to)
  const canDelete = canDeleteRequest(request.created_by)
  const canComment = canCommentOnRequest(request.created_by)

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12">
          <div className="flex items-center gap-2 px-4">
            <SidebarTrigger className="-ml-1" />
            <Separator
              orientation="vertical"
              className="mr-2 data-[orientation=vertical]:h-4"
            />
            <Breadcrumb>
              <BreadcrumbList>
                <BreadcrumbItem className="hidden md:block">
                  <BreadcrumbLink href="/dashboard">
                    Dashboard
                  </BreadcrumbLink>
                </BreadcrumbItem>
                <BreadcrumbSeparator className="hidden md:block" />
                <BreadcrumbItem>
                  <BreadcrumbLink href="/reque/my-requests">
                    ReQue
                  </BreadcrumbLink>
                </BreadcrumbItem>
                <BreadcrumbSeparator className="hidden md:block" />
                <BreadcrumbItem>
                  <BreadcrumbPage>Request Details</BreadcrumbPage>
                </BreadcrumbItem>
              </BreadcrumbList>
            </Breadcrumb>
          </div>
        </header>
        <div className="flex flex-1 flex-col gap-6 p-6 pt-0">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold tracking-tight">{request.title}</h1>
              <div className="flex items-center gap-2 mt-2">
                <Badge className={statusColors[request.status]}>{request.status.replace('_', ' ')}</Badge>
                <Badge className={priorityColors[request.priority]}>{request.priority}</Badge>
              </div>
            </div>
            {canDelete && (
              <Button variant="destructive" onClick={handleDeleteRequest}>
                <Trash2 className="h-4 w-4 mr-2" />
                Delete
              </Button>
            )}
          </div>

          <div className="grid gap-6 lg:grid-cols-3">
            <div className="lg:col-span-2 space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle>Description</CardTitle>
                </CardHeader>
                <CardContent>
                  {request.description ? (
                    <p className="whitespace-pre-wrap text-sm">{request.description}</p>
                  ) : (
                    <p className="text-sm text-muted-foreground">No description provided</p>
                  )}
                </CardContent>
              </Card>

              {canComment && (
                <Card>
                  <CardHeader>
                    <CardTitle>Add Comment</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <Textarea
                      placeholder="Write a comment..."
                      value={commentText}
                      onChange={(e) => setCommentText(e.target.value)}
                      disabled={submittingComment}
                      rows={3}
                    />
                    <Button onClick={handleSubmitComment} disabled={submittingComment || !commentText.trim()}>
                      {submittingComment ? 'Posting...' : 'Post Comment'}
                    </Button>
                  </CardContent>
                </Card>
              )}

              <Card>
                <CardHeader>
                  <CardTitle>Comments ({comments.length})</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  {comments.length === 0 ? (
                    <p className="text-sm text-muted-foreground">No comments yet</p>
                  ) : (
                    comments.map((comment) => {
                      const commentProfile = profiles.get(comment.user_id)
                      return (
                        <div key={comment.id} className="flex gap-4">
                          <Avatar>
                            <AvatarImage src={commentProfile?.avatar_url || ''} />
                            <AvatarFallback>
                              {commentProfile?.full_name?.charAt(0) || 'U'}
                            </AvatarFallback>
                          </Avatar>
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="font-medium text-sm">
                                {commentProfile?.full_name || 'Unknown User'}
                              </span>
                              <span className="text-xs text-muted-foreground">
                                {format(new Date(comment.created_at), 'MMM d, yyyy h:mm a')}
                              </span>
                            </div>
                            <p className="text-sm whitespace-pre-wrap">{comment.comment_text}</p>
                          </div>
                        </div>
                      )
                    })
                  )}
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Activity</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  {activity.length === 0 ? (
                    <p className="text-sm text-muted-foreground">No activity yet</p>
                  ) : (
                    activity.map((item) => {
                      const actorProfile = profiles.get(item.user_id)
                      return (
                        <div key={item.id} className="flex gap-3 text-sm">
                          <Clock className="h-4 w-4 text-muted-foreground mt-0.5" />
                          <div className="flex-1">
                            <p>
                              <span className="font-medium">{actorProfile?.full_name || 'User'}</span>
                              {' '}
                              {item.activity_type.replace('_', ' ')}
                              {item.new_value && ` to ${item.new_value}`}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {format(new Date(item.created_at), 'MMM d, yyyy h:mm a')}
                            </p>
                          </div>
                        </div>
                      )
                    })
                  )}
                </CardContent>
              </Card>
            </div>

            <div className="space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle>Details</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label className="text-sm font-medium flex items-center gap-2">
                      <User className="h-4 w-4" />
                      Created By
                    </Label>
                    <p className="text-sm">{creatorProfile?.full_name || 'Unknown'}</p>
                  </div>

                  <div className="space-y-2">
                    <Label className="text-sm font-medium flex items-center gap-2">
                      <Calendar className="h-4 w-4" />
                      Created
                    </Label>
                    <p className="text-sm">{format(new Date(request.created_at), 'MMM d, yyyy h:mm a')}</p>
                  </div>

                  {request.due_date && (
                    <div className="space-y-2">
                      <Label className="text-sm font-medium flex items-center gap-2">
                        <Calendar className="h-4 w-4" />
                        Due Date
                      </Label>
                      <p className="text-sm">{format(new Date(request.due_date), 'MMM d, yyyy')}</p>
                    </div>
                  )}
                </CardContent>
              </Card>

              {canEdit && (
                <Card>
                  <CardHeader>
                    <CardTitle>Update Status</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="space-y-2">
                      <Label>Status</Label>
                      <Select value={request.status} onValueChange={handleStatusChange}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="new">New</SelectItem>
                          <SelectItem value="in_progress">In Progress</SelectItem>
                          <SelectItem value="under_review">Under Review</SelectItem>
                          <SelectItem value="completed">Completed</SelectItem>
                          <SelectItem value="rejected">Rejected</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>

                    <div className="space-y-2">
                      <Label>Priority</Label>
                      <Select value={request.priority} onValueChange={handlePriorityChange}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="normal">Normal</SelectItem>
                          <SelectItem value="high">High</SelectItem>
                          <SelectItem value="urgent">Urgent</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>
          </div>
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}

function Label({ children, className }: { children: React.ReactNode; className?: string }) {
  return <label className={className}>{children}</label>
}
