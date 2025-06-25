module Admin
  class ConfirmEmailChangesController < Admin::ApplicationController
    before_action :set_conflict, only: [:show, :compare, :merge, :reject, :destroy]
    
    def index
      search_term = params[:search].to_s.strip
      status_filter = params[:status].to_s.strip
      
      resources = ConfirmEmailChange.all.includes(:replace_person, :replace_with)
      
      if search_term.present?
        resources = resources.joins(:replace_person, :replace_with)
                           .where("people.firstname ILIKE ? OR people.lastname ILIKE ? OR confirm_email_changes.replace_email ILIKE ?", 
                                  "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
      end
      
      # Apply status filtering
      case status_filter
      when 'pending'
        resources = resources.where(confirmed: false)
      when 'resolved'
        resources = resources.where(confirmed: true)
      when 'high_priority'
        resources = resources.where(priority: 'high')
      when 'recent_invitations'
        resources = resources.where(has_recent_invitations: true)
      end
      
      resources = resources.order(confirmed: :asc, created_at: :desc)
      
      # Simple pagination
      per_page = 20
      page = params[:page].to_i
      page = 1 if page < 1
      
      @resources = if resources.respond_to?(:page)
                     resources.page(page).per(per_page)
                   else
                     resources.limit(per_page).offset((page - 1) * per_page)
                   end
      
      # System-wide totals (not filtered/paginated)
      @total_stats = {
        pending: ConfirmEmailChange.where(confirmed: false).count,
        resolved: ConfirmEmailChange.where(confirmed: true).count,
        high_priority: ConfirmEmailChange.where(priority: 'high').count,
        recent_invitations: ConfirmEmailChange.where(has_recent_invitations: true).count,
        total: ConfirmEmailChange.count
      }
    end
    
    def show
      @resource = @conflict # Set @resource for the view
      @comparison = prepare_comparison
      return if @comparison.nil? # Redirect already happened in prepare_comparison
      @recommendation = @comparison[:recommendation]
    end
    
    # Custom action for detailed comparison view
    def compare
      @resource = @conflict # Set @resource for the view
      @comparison = prepare_comparison
      return if @comparison.nil? # Redirect already happened in prepare_comparison
      @recommendation = @comparison[:recommendation]
      render 'show' # Use the same view for now
    end
    
    # Action to merge persons (keep recommended)
    def merge
      @comparison = prepare_comparison
      target_person = @comparison[:recommendation][:keep]
      source_person = @comparison[:recommendation][:replace]
      
      begin
        result = merge_persons(target_person, source_person)
        if result[:success]
          redirect_to admin_confirm_email_changes_path, 
                     notice: "Successfully merged #{source_person.name} into #{target_person.name}. #{result[:details]}"
        else
          redirect_to admin_confirm_email_change_path(@conflict),
                     alert: "Merge failed: #{result[:error]}"
        end
      rescue => e
        redirect_to admin_confirm_email_change_path(@conflict),
                   alert: "Merge failed: #{e.message}"
      end
    end
    
    # Action to merge persons (keep opposite of recommendation)
    def merge_opposite
      @comparison = prepare_comparison
      target_person = @comparison[:recommendation][:replace]
      source_person = @comparison[:recommendation][:keep]
      
      begin
        result = merge_persons(target_person, source_person)
        if result[:success]
          redirect_to admin_confirm_email_changes_path,
                     notice: "Successfully merged #{source_person.name} into #{target_person.name}. #{result[:details]}"
        else
          redirect_to admin_confirm_email_change_path(@conflict),
                     alert: "Merge failed: #{result[:error]}"
        end
      rescue => e
        redirect_to admin_confirm_email_change_path(@conflict),
                   alert: "Merge failed: #{e.message}"
      end
    end
    
    # Action to reject/skip the conflict
    def reject
      @conflict.update!(
        confirmed: true,
        reviewed_by: current_user.email,
        reviewed_at: Time.current,
        auto_merge_blocked_reason: params[:reason] || 'Manually rejected by admin'
      )
      
      redirect_to admin_confirm_email_changes_path,
                 notice: "Conflict marked as resolved (no merge performed)"
    end
    
    def destroy
      # Get details before deletion for better feedback message
      person1_info = @conflict.replace_person&.name || "Person #{@conflict.replace_person_id} (missing)"
      person2_info = @conflict.replace_with&.name || "Person #{@conflict.replace_with_id} (missing)"
      conflict_email = @conflict.replace_email
      conflict_id = @conflict.id
      
      # Log the deletion for audit trail
      Rails.logger.info "🗑️  CONFLICT DELETION - ID: #{conflict_id}, User: #{current_user.email}, Person1: #{person1_info}, Person2: #{person2_info}, Email: #{conflict_email}, Time: #{Time.current}"
      
      # Create audit record before destroying
      begin
        PersonMergeAudit.create!(
          source_person_id: @conflict.replace_person_id,
          target_person_id: @conflict.replace_with_id,
          source_email: @conflict.replace_email,
          target_email: @conflict.replace_with_email,
          merge_reason: "CONFLICT RECORD DELETED - #{person1_info} ↔ #{person2_info}",
          initiated_by: current_user.email,
          completed: true,
          affected_memberships: [],
          affected_invitations: []
        )
      rescue => e
        Rails.logger.warn "Failed to create deletion audit: #{e.message}"
      end
      
      @conflict.destroy
      
      # Create clear messaging based on what type of cleanup this is
      if person1_info.include?("missing") || person2_info.include?("missing")
        # Orphaned conflict cleanup
        existing_person = person1_info.include?("missing") ? person2_info : person1_info
        missing_person = person1_info.include?("missing") ? person1_info : person2_info
        missing_id = missing_person.match(/Person (\d+)/)[1] rescue "unknown"
        
        message = "Cleaned up orphaned conflict record ##{conflict_id}: Person #{missing_id} no longer exists, was linked to #{existing_person} (#{conflict_email})"
      else
        # Normal conflict deletion
        message = "Deleted conflict record ##{conflict_id}: #{person1_info} and #{person2_info} (#{conflict_email})"
      end
      
      redirect_to admin_confirm_email_changes_path, notice: message
    end
    
    private
    
    def set_conflict
      @conflict = ConfirmEmailChange.find(params[:id])
    end
    
    def prepare_comparison
      person1 = Person.find_by(id: @conflict.replace_person_id)
      person2 = Person.find_by(id: @conflict.replace_with_id)
      
      # Handle missing persons
      if person1.nil? || person2.nil?
        missing_ids = []
        missing_ids << @conflict.replace_person_id if person1.nil?
        missing_ids << @conflict.replace_with_id if person2.nil?
        
        redirect_to admin_confirm_email_changes_path, 
                   alert: "Cannot compare: Person(s) with ID(s) #{missing_ids.join(', ')} no longer exist. Consider deleting this conflict record."
        return nil
      end
      
      comparison_service = ComparePersons.new(person1, person2)
      better_record = comparison_service.better_record
      
      {
        person1: {
          record: person1,
          data_score: comparison_service.data_score(person1),
          membership_count: person1.memberships.count,
          lecture_count: person1.lectures.count,
          has_user_account: !person1.user.nil?,
          last_activity: person1.updated_at,
          completeness: calculate_completeness(person1)
        },
        person2: {
          record: person2,
          data_score: comparison_service.data_score(person2),
          membership_count: person2.memberships.count,
          lecture_count: person2.lectures.count,
          has_user_account: !person2.user.nil?,
          last_activity: person2.updated_at,
          completeness: calculate_completeness(person2)
        },
        recommendation: {
          keep: better_record,
          replace: better_record == person1 ? person2 : person1,
          reason: recommendation_reason(comparison_service, person1, person2),
          confidence: calculate_confidence(comparison_service, person1, person2)
        },
        conflict_info: {
          created_at: @conflict.created_at,
          priority: @conflict.priority,
          has_recent_invitations: @conflict.has_recent_invitations,
          blocked_reason: @conflict.auto_merge_blocked_reason
        }
      }
    end
    
    def calculate_completeness(person)
      total_fields = 14
      filled_fields = 0
      
      filled_fields += 1 unless person.firstname.blank?
      filled_fields += 1 unless person.lastname.blank?
      filled_fields += 1 unless person.email.blank?
      filled_fields += 1 unless person.affiliation.blank?
      filled_fields += 1 unless person.title.blank?
      filled_fields += 1 unless person.address1.blank?
      filled_fields += 1 unless person.city.blank?
      filled_fields += 1 unless person.region.blank?
      filled_fields += 1 unless person.country.blank?
      filled_fields += 1 unless person.postal_code.blank?
      filled_fields += 1 unless person.phone.blank?
      filled_fields += 1 unless person.gender.blank?
      filled_fields += 1 unless person.academic_status.blank?
      filled_fields += 1 unless person.phd_year.blank?
      
      (filled_fields.to_f / total_fields * 100).round(1)
    end
    
    def recommendation_reason(comparison_service, person1, person2)
      better = comparison_service.better_record
      reasons = []
      
      if better.memberships.count > (better == person1 ? person2 : person1).memberships.count
        reasons << "more event memberships (#{better.memberships.count} vs #{(better == person1 ? person2 : person1).memberships.count})"
      end
      
      if !better.user.nil? && (better == person1 ? person2 : person1).user.nil?
        reasons << "has user account"
      end
      
      if better.lectures.count > (better == person1 ? person2 : person1).lectures.count
        reasons << "more lectures (#{better.lectures.count} vs #{(better == person1 ? person2 : person1).lectures.count})"
      end
      
      if calculate_completeness(better) > calculate_completeness(better == person1 ? person2 : person1)
        reasons << "more complete profile data"
      end
      
      if better.updated_at > (better == person1 ? person2 : person1).updated_at
        reasons << "more recently updated"
      end
      
      reasons.empty? ? "similar data quality" : reasons.join(", ")
    end
    
    def calculate_confidence(comparison_service, person1, person2)
      score1 = comparison_service.data_score(person1)
      score2 = comparison_service.data_score(person2)
      
      if score1 == score2
        return :low
      elsif (score1 - score2).abs < 50
        return :medium
      else
        return :high
      end
    end
    
    def merge_persons(target_person, source_person)
      ActiveRecord::Base.transaction do
        # Track the merge in audit table
        audit = PersonMergeAudit.create!(
          source_person_id: source_person.id,
          target_person_id: target_person.id,
          source_email: source_person.email,
          target_email: target_person.email,
          merge_reason: "Admin manual merge via conflict resolution",
          initiated_by: current_user.email,
          affected_memberships: source_person.memberships.pluck(:id),
          affected_invitations: source_person.invitations.pluck(:id)
        )
        
        # Move memberships
        memberships_moved = 0
        source_person.memberships.each do |membership|
          existing = target_person.memberships.find_by(event_id: membership.event_id)
          if existing
            # Mark as deleted instead of hard delete
            membership.update!(
              deleted_at: Time.current,
              deleted_by: current_user.email,
              deletion_reason: "Duplicate membership during person merge"
            )
          else
            membership.update!(person_id: target_person.id)
            memberships_moved += 1
          end
        end
        
        # Move lectures
        lectures_moved = source_person.lectures.count
        source_person.lectures.update_all(person_id: target_person.id)
        
        # Move invitations
        invitations_moved = source_person.invitations.count
        source_person.invitations.update_all(invited_by: target_person.id)
        
        # Handle user account
        if source_person.user && !target_person.user
          source_person.user.update!(person_id: target_person.id)
        elsif source_person.user && target_person.user
          # Can't merge user accounts - mark source as deleted
          source_person.user.update!(
            deleted_at: Time.current,
            deletion_reason: "Duplicate user account during person merge"
          ) if source_person.user.respond_to?(:deleted_at)
        end
        
        # Soft delete source person
        if source_person.respond_to?(:deleted_at)
          source_person.update!(deleted_at: Time.current)
        end
        
        # Mark conflict as resolved
        @conflict.update!(
          confirmed: true,
          reviewed_by: current_user.email,
          reviewed_at: Time.current
        )
        
        # Complete audit record
        audit.update!(completed: true)
        
        {
          success: true,
          details: "Moved #{memberships_moved} memberships, #{lectures_moved} lectures, #{invitations_moved} invitations"
        }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end
end
