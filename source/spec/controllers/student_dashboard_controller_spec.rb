require 'rails_helper'

RSpec.describe StudentDashboardController, type: :controller do
  before(:each) do
    Evaluation.destroy_all
    Team.destroy_all
    Project.destroy_all
  end

  let!(:student) do
    User.find_or_create_by(email: 'student@example.com') do |user|
      user.role = 'student'
      user.first_name = 'Jane'
      user.last_name = 'Doe'
      user.password = 'password'
      user.sex = 'male'
      user.student_id = 40_001_111
    end
  end
  let!(:student2) do
    User.find_or_create_by(email: 'student_2@example.com') do |user|
      user.role = 'student'
      user.first_name = 'Joe'
      user.last_name = 'Smith'
      user.password = 'password'
      user.sex = 'female'
      user.student_id = 40_002_222
    end
  end
  let!(:instructor) do
    User.find_or_create_by(email: 'instructor@example.com') do |user|
      user.role = 'instructor'
      user.first_name = 'John'
      user.last_name = 'Doe'
      user.password = 'password'
      user.sex = 'male'
      user.student_id = 40_003_333
    end
  end
  let!(:course) { Course.find_or_create_by(title: 'Software Engineering Processes', code: 'SOEN341', instructor: instructor) }
  let!(:project) do
    Project.find_or_create_by(title: 'Project Alpha', description: 'A project to test the peer assessment system.',
                              due_date: 1.week.from_now, course: course)
  end
  let!(:team) { Team.find_or_create_by(name: 'Team A', project: project, description: 'A team working on Project Alpha') }
  let!(:completed_evaluation) do
    Evaluation.find_or_create_by(evaluator: student2, evaluatee: student, project: project, team: team) do |evaluation|
      evaluation.conceptual_rating = 5.0
      evaluation.cooperation_rating = 5.0
      evaluation.practical_rating = 5.0
      evaluation.work_ethic_rating = 5.0
      evaluation.comment = 'Good effort'
    end
  end
  let!(:pending_evaluation) do
    Evaluation.find_or_create_by(evaluator: student, evaluatee: student2, project: project, team: team) do |evaluation|
      evaluation.conceptual_rating = nil
      evaluation.cooperation_rating = nil
      evaluation.practical_rating = nil
      evaluation.work_ethic_rating = nil
      evaluation.comment = nil
    end
  end

  before do
    sign_in student
    course.enroll([student, student2])
  end

  describe 'GET #teams' do
    it 'assigns @teams_by_project' do
      teams_service = instance_double(TeamsService, teams_by_project: 'mocked_teams')
      allow(TeamsService).to receive(:new).and_return(teams_service)

      get :teams, params: { course_id: course.id }
      expect(assigns(:teams_by_project)).to eq('mocked_teams')
      expect(response).to render_template(:teams)
    end
  end

  describe 'GET #evaluations' do
    it 'assigns @student_evaluations' do
      get :evaluations, params: { course_id: course.id }
      expect(assigns(:student_evaluations)).to be_present
      expect(response).to render_template(:evaluations)
    end
  end

  describe 'GET #feedback' do
    it 'assigns @avg_ratings and @received_evaluations' do
      get :feedback, params: { course_id: course.id }
      expect(assigns(:avg_ratings)).to be_present
      expect(assigns(:received_evaluations)).to be_present
      expect(response).to render_template(:feedback)
    end
  end

  describe 'GET #new_evaluation' do
    it 'assigns @course, @projects, and @evaluatees' do
      get :new_evaluation, params: { course_id: course.id }
      expect(assigns(:course)).to eq(course)
      expect(assigns(:projects)).to include(project)
      expect(response).to render_template(:new_evaluation)
    end
  end

  describe 'POST #submit_evaluation' do
    context 'when evaluation is successfully updated' do
      it 'redirects to evaluations path with success notice' do
        post :submit_evaluation,
             params: { course_id: course.id,
                       evaluation: { id: pending_evaluation.id, cooperation_rating: 4, conceptual_rating: 4,
                                     practical_rating: 4, work_ethic_rating: 4, comment: 'Good job' } }
        expect(response).to redirect_to(evaluations_student_dashboard_index_path(course_id:
                                                                                 pending_evaluation.project.course_id))
        expect(flash[:notice]).to eq('Evaluation submitted successfully.')
      end
    end

    context 'when evaluation fails to update' do
      before do
        allow_any_instance_of(Evaluation).to receive(:update).and_return(false)
      end

      it 'redirects back to new evaluation path with failure alert' do
        post :submit_evaluation, params: { course_id: course.id, evaluation: { id: pending_evaluation.id } }
        expect(response).to redirect_to(new_evaluation_student_dashboard_index_path(
                                          course_id: pending_evaluation.project.course_id
                                        ))
        expect(flash[:alert]).to eq('Failed to submit evaluation. Please try again.')
      end
    end
  end

  describe 'private methods' do
    describe '#ensure_student_role' do
      context 'when user is not a student' do
        before do
          sign_in instructor
        end

        it 'redirects to root path with access denied alert' do
          get :index # triggers ensure_student_role
          expect(flash[:alert]).to eq('Access denied. Students only.')
          expect(response).to redirect_to(root_path)
        end
      end
    end

    describe '#set_student' do
      it 'assigns @student as the current user if role is student' do
        controller.send(:set_student)
        expect(assigns(:student)).to eq(student)
      end
    end

    describe '#upcoming_evaluations' do
      it 'returns upcoming evaluations for the selected course' do
        get :evaluations, params: { course_id: course.id }
        result = controller.send(:upcoming_evaluations)
        expect(result).to be_a(Array)
      end
    end

    describe '#avg_ratings' do
      it 'returns average ratings for completed evaluations' do
        get :index, params: { course_id: course.id, student: student } # trigger avg_ratings
        result = controller.send(:avg_ratings)

        expect(result[:Conceptual]).to eq(5.0)
        expect(result[:Cooperation]).to eq(5.0)
        expect(result[:Practical]).to eq(5.0)
        expect(result[:'Work Ethic']).to eq(5.0)
      end
    end

    describe '#student_evaluations' do
      it 'returns a list of evaluations for the student' do
        result = controller.send(:student_evaluations)
        expect(result).to be_an(Array)
      end
    end

    describe '#received_evaluations' do
      it 'returns a list of received evaluations' do
        get :feedback, params: { course_id: course.id } # trigger received_evaluations
        result = controller.send(:received_evaluations)
        expect(result).to be_a(Array)
      end
    end
  end
end
