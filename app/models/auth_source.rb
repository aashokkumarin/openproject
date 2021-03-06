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

class AuthSource < ActiveRecord::Base
  include Redmine::Ciphering

  has_many :users

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 60

  def authenticate(login, password)
  end

  def test_connection
  end

  def auth_method_name
    "Abstract"
  end

  def account_password
    read_ciphered_attribute(:account_password)
  end

  def account_password=(arg)
    write_ciphered_attribute(:account_password, arg)
  end

  def allow_password_changes?
    self.class.allow_password_changes?
  end

  # Does this auth source backend allow password changes?
  def self.allow_password_changes?
    false
  end

  # Try to authenticate a user not yet registered against available sources
  def self.authenticate(login, password)
    AuthSource.find(:all, :conditions => ["onthefly_register=?", true]).each do |source|
      begin
        logger.debug "Authenticating '#{login}' against '#{source.name}'" if logger && logger.debug?
        attrs = source.authenticate(login, password)
      rescue => e
        logger.error "Error during authentication: #{e.message}"
        attrs = nil
      end
      return attrs if attrs
    end
    return nil
  end
end
