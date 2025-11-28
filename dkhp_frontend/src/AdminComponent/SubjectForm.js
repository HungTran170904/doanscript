import { Col, Form, Row } from "react-bootstrap";

const SubjectForm=({newSubject})=>{
          const handleOnChange=(e, fieldName)=>{
                    newSubject[fieldName]=e.target.value;
          }
          return(
                    <Form>
                              <Row>
                                        <Form.Group as={Col} controlId="subjectId">
                                                  <Form.Label>Mã môn học</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"subjectId")}/>
                                        </Form.Group>
                                        <Form.Group as={Col} controlId="subjectName">
                                                  <Form.Label>Tên môn học</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"subjectName")}/>
                                        </Form.Group>
                              </Row>
                              <Row>
                                        <Form.Group as={Col} controlId="theoryCreditNumber">
                                                  <Form.Label>Số TCLT</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"theoryCreditNumber")}/>
                                        </Form.Group>
                                        <Form.Group as={Col} controlId="practiceCreditNumber">
                                                  <Form.Label>Số TCTH</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"practiceCreditNumber")}/>
                                        </Form.Group>
                              </Row>
                              <Row>
                                        <Form.Group as={Col} controlId="prerequisiteSubjectIds">
                                                  <Form.Label>Mã các MH tiên quyết (cách nhau dấu phẩy)</Form.Label>
                                                  <Form.Control as="textarea" rows={2} onChange={(e)=>handleOnChange(e,"prerequisiteSubjectIds")}/>
                                        </Form.Group>
                              </Row>
                              <Row>
                                        <Form.Group as={Col} controlId="aheadSubjectIds">
                                                  <Form.Label>Mã các MH học trước (cách nhau dấu phẩy)</Form.Label>
                                                  <Form.Control as="textarea" rows={2} onChange={(e)=>handleOnChange(e,"aheadSubjectIds")}/>
                                        </Form.Group>
                              </Row>
                    </Form>
          )
}
export default SubjectForm;