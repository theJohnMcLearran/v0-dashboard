'use client'

import { useState } from 'react'
import Link from 'next/link'
import { format } from 'date-fns'
import type { Request } from '@/lib/supabase/types'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Eye } from 'lucide-react'

interface RequestListProps {
  requests: Request[]
  loading: boolean
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

const statusLabels = {
  new: 'New',
  in_progress: 'In Progress',
  under_review: 'Under Review',
  completed: 'Completed',
  rejected: 'Rejected',
}

const priorityLabels = {
  normal: 'Normal',
  high: 'High',
  urgent: 'Urgent',
}

export function RequestList({ requests, loading }: RequestListProps) {
  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Loading requests...</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-16 bg-muted animate-pulse rounded" />
            ))}
          </div>
        </CardContent>
      </Card>
    )
  }

  if (requests.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>No Requests Found</CardTitle>
          <CardDescription>
            There are no requests to display. Create your first request to get started.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex justify-center py-8">
          <Link href="/reque/new">
            <Button>Create New Request</Button>
          </Link>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Requests</CardTitle>
        <CardDescription>
          Manage and track all requests
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Title</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Priority</TableHead>
              <TableHead>Due Date</TableHead>
              <TableHead>Created</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {requests.map((request) => (
              <TableRow key={request.id}>
                <TableCell className="font-medium">
                  <Link href={`/reque/request/${request.id}`} className="hover:underline">
                    {request.title}
                  </Link>
                </TableCell>
                <TableCell>
                  <Badge className={statusColors[request.status]}>
                    {statusLabels[request.status]}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge className={priorityColors[request.priority]}>
                    {priorityLabels[request.priority]}
                  </Badge>
                </TableCell>
                <TableCell>
                  {request.due_date ? format(new Date(request.due_date), 'MMM d, yyyy') : 'No due date'}
                </TableCell>
                <TableCell>
                  {format(new Date(request.created_at), 'MMM d, yyyy')}
                </TableCell>
                <TableCell className="text-right">
                  <Link href={`/reque/request/${request.id}`}>
                    <Button variant="ghost" size="sm">
                      <Eye className="h-4 w-4 mr-2" />
                      View
                    </Button>
                  </Link>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}
