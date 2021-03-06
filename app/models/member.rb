#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
#
# Copyright (C) 2012-2013 the OpenProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

class Member < ActiveRecord::Base
  belongs_to :user
  belongs_to :principal, :foreign_key => 'user_id'
  has_many :member_roles, :dependent => :destroy, :autosave => true
  has_many :roles, :through => :member_roles
  belongs_to :project

  attr_protected :project_id, :user_id, :role_ids

  validates_presence_of :principal, :project
  validates_uniqueness_of :user_id, :scope => :project_id

  validate :validate_presence_of_role

  before_destroy :remove_from_category_assignments
  after_destroy :unwatch_from_permission_change

  def name
    self.user.name
  end

  alias :base_role_ids= :role_ids=
  def role_ids=(arg)
    ids = (arg || []).collect(&:to_i) - [0]
    # Keep inherited roles
    ids += member_roles.select {|mr| !mr.inherited_from.nil?}.collect(&:role_id)

    new_role_ids = ids - role_ids
    # Add new roles
    new_role_ids.each {|id| member_roles << MemberRole.new.tap {|r| r.role_id = id } }
    # Remove roles (Rails' #role_ids= will not trigger MemberRole#on_destroy)
    member_roles_to_destroy = member_roles.select {|mr| !ids.include?(mr.role_id)}
    if member_roles_to_destroy.any?
      member_roles_to_destroy.each(&:destroy)
      unwatch_from_permission_change
    end
  end

  def <=>(member)
    a, b = roles.sort.first, member.roles.sort.first
    a == b ? (principal <=> member.principal) : (a <=> b)
  end

  def deletable?
    member_roles.detect {|mr| mr.inherited_from}.nil?
  end

  def include?(user)
    if principal.is_a?(Group)
      !user.nil? && user.groups.include?(principal)
    else
      self.user == user
    end
  end

  # remove category based auto assignments for this member
  def remove_from_category_assignments
    IssueCategory.update_all "assigned_to_id = NULL", ["project_id = ? AND assigned_to_id = ?", project.id, user.id] if user
  end

  # Find or initilize a Member with an id, attributes, and for a Principal
  def self.edit_membership(id, new_attributes, principal=nil)
    @membership = id.present? ? Member.find(id) : Member.new(:principal => principal)
    # interface refactoring needed
    # not critical atm because only admins can invoke it (see users and groups controllers)
    @membership.force_attributes = new_attributes
    @membership
  end

  protected

  def validate_presence_of_role
    errors.add_on_empty :roles if member_roles.empty? && roles.empty? || !member_roles.empty? && member_roles.all?(&:marked_for_destruction?)
  end

  private

  # Unwatch things that the user is no longer allowed to view inside project
  def unwatch_from_permission_change
    if user
      Watcher.prune(:user => user, :project => project)
    end
  end
end
