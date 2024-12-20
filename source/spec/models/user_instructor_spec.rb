require 'rails_helper'

RSpec.describe User, type: :model do
  let(:instructor) do
    User.find_or_initialize_by(email: 'instructor@example.com')
  end

  describe 'instructor' do
    it 'can teach one or many courses' do
      course = Course.find_or_initialize_by(code: 'SOEN 341')
      course.update!(title: 'Software Process', instructor_id: instructor.id)
      expect(instructor.courses_taught.count).to eq(3)
    end
  end
end
