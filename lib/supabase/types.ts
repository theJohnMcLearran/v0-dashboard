export type UserRole = 'admin' | 'team_member' | 'user' | 'guest'
export type RequestStatus = 'new' | 'in_progress' | 'under_review' | 'completed' | 'rejected'
export type RequestPriority = 'normal' | 'high' | 'urgent'

export interface Profile {
  id: string
  email: string
  full_name: string | null
  avatar_url: string | null
  role: UserRole
  created_at: string
  updated_at: string
}

export interface Request {
  id: string
  title: string
  description: string | null
  status: RequestStatus
  priority: RequestPriority
  due_date: string | null
  created_by: string
  assigned_to: string | null
  created_at: string
  updated_at: string
}

export interface RequestAttachment {
  id: string
  request_id: string
  file_url: string
  filename: string
  file_size: number | null
  mime_type: string | null
  uploaded_by: string
  created_at: string
}

export interface RequestComment {
  id: string
  request_id: string
  user_id: string
  comment_text: string
  created_at: string
  updated_at: string
}

export interface RequestActivity {
  id: string
  request_id: string
  user_id: string
  activity_type: string
  old_value: string | null
  new_value: string | null
  created_at: string
}

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: Profile
        Insert: Omit<Profile, 'created_at' | 'updated_at'>
        Update: Partial<Omit<Profile, 'id' | 'created_at'>>
        Relationships: []
      }
      requests: {
        Row: Request
        Insert: Omit<Request, 'id' | 'created_at' | 'updated_at'>
        Update: Partial<Omit<Request, 'id' | 'created_at'>>
        Relationships: []
      }
      request_attachments: {
        Row: RequestAttachment
        Insert: Omit<RequestAttachment, 'id' | 'created_at'>
        Update: Partial<Omit<RequestAttachment, 'id' | 'created_at'>>
        Relationships: []
      }
      request_comments: {
        Row: RequestComment
        Insert: Omit<RequestComment, 'id' | 'created_at' | 'updated_at'>
        Update: Partial<Omit<RequestComment, 'id' | 'created_at'>>
        Relationships: []
      }
      request_activity: {
        Row: RequestActivity
        Insert: Omit<RequestActivity, 'id' | 'created_at'>
        Update: Partial<Omit<RequestActivity, 'id' | 'created_at'>>
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      user_role: UserRole
      request_status: RequestStatus
      request_priority: RequestPriority
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}
