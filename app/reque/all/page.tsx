'use client'

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
import { RequestList } from '@/components/request-list'
import { useRequests } from '@/hooks/use-requests'
import { usePermissions } from '@/hooks/use-permissions'
import { useRouter } from 'next/navigation'
import { useEffect } from 'react'

export default function AllRequestsPage() {
  return (
    <ProtectedRoute>
      <AllRequestsContent />
    </ProtectedRoute>
  )
}

function AllRequestsContent() {
  const { requests, loading } = useRequests()
  const { canViewAllRequests } = usePermissions()
  const router = useRouter()

  useEffect(() => {
    if (!loading && !canViewAllRequests) {
      router.push('/reque/my-requests')
    }
  }, [canViewAllRequests, loading, router])

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
                  <BreadcrumbLink href="/reque/all">
                    ReQue
                  </BreadcrumbLink>
                </BreadcrumbItem>
                <BreadcrumbSeparator className="hidden md:block" />
                <BreadcrumbItem>
                  <BreadcrumbPage>All Requests</BreadcrumbPage>
                </BreadcrumbItem>
              </BreadcrumbList>
            </Breadcrumb>
          </div>
        </header>
        <div className="flex flex-1 flex-col gap-6 p-6 pt-0">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">All Requests</h1>
            <p className="text-muted-foreground">View and manage all requests in the system</p>
          </div>

          <RequestList requests={requests} loading={loading} />
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
